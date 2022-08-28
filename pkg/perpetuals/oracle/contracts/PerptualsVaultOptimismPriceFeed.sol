// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

// solhint-disable-next-line max-line-length
import { IPerpetualsVaultPriceFeed } from "@koyofinance/contracts-interfaces/contracts/perpetuals/oracle/IPerpetualsVaultPriceFeed.sol";
import { Authentication } from "@koyofinance/contracts-solidity-utils/contracts/helpers/Authentication.sol";
import { IVault as IExchangeVault } from "@koyofinance/contracts-interfaces/contracts/vault/IVault.sol";
import { IAuthorizer } from "@koyofinance/contracts-interfaces/contracts/vault/IAuthorizer.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsPriceFeed } from "@koyofinance/contracts-interfaces/contracts/perpetuals/oracle/IPerpetualsPriceFeed.sol";
// solhint-disable-next-line max-line-length
import { IPerpetualsSecondaryPriceFeed } from "@koyofinance/contracts-interfaces/contracts/perpetuals/oracle/IPerpetualsSecondaryPriceFeed.sol";
// solhint-disable-next-line max-line-length
import { AggregatorV2V3Interface } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/chainlink/AggregatorV2V3Interface.sol";
// solhint-disable-next-line max-line-length
import { IVelodromePair } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/velodrome/IVelodromePair.sol";

// solhint-disable-next-line max-line-length
import { Errors, _require, _revert } from "@koyofinance/contracts-interfaces/contracts/solidity-utils/helpers/KoyoErrors.sol";
import { SafeMath } from "@koyofinance/contracts-solidity-utils/contracts/openzeppelin/SafeMath.sol";

contract PerptualsVaultOptimismPriceFeed is IPerpetualsVaultPriceFeed, Authentication {
    using SafeMath for uint256;

    uint256 public constant PRICE_PRECISION = 10**30;
    uint256 public constant ONE_USD = PRICE_PRECISION;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant MAX_SPREAD_BASIS_POINTS = 50;
    uint256 public constant MAX_ADJUSTMENT_INTERVAL = 2 hours;
    uint256 public constant MAX_ADJUSTMENT_BASIS_POINTS = 20;

    uint256 public constant CHAINLINK_SEQUENCER_GRACE_PERIOD_TIME = 1 hours;

    IExchangeVault private immutable _exchangeVault;

    struct Slot0 {
        bool isAmmEnabled; // 8/256
        bool isSecondaryPriceEnabled; // 16/256
        bool useV2Pricing; // 24/256
        bool favorPrimaryPrice; // 32/256
        uint8 priceSampleSpace; // 40/256
        uint16 spreadThresholdBasisPoints; // 56/256
        uint160 maxStrictPriceDeviation; //  216/256
    }
    Slot0 public slot0;

    address public chainlinkSequencesStatusOracle;

    address public secondaryPriceFeed;

    mapping(address => address) public priceFeeds;
    mapping(address => uint256) public priceDecimals;
    mapping(address => uint256) public spreadBasisPoints;
    // Chainlink can return prices for stablecoins
    // that differs from 1 USD by a larger percentage than stableSwapFeeBasisPoints
    // we use strictStableTokens to cap the price to 1 USD
    // this allows us to configure stablecoins like DAI as being a stableToken
    // while not being a strictStableToken
    mapping(address => bool) public strictStableTokens;

    mapping(address => uint256) public override adjustmentBasisPoints;
    mapping(address => bool) public override isAdjustmentAdditive;
    mapping(address => uint256) public lastAdjustmentTimings;

    constructor(IExchangeVault exchangeVault, address _chainlinkSequencesStatusOracle)
        Authentication(bytes32(uint256(address(this))))
    {
        _exchangeVault = exchangeVault;
        chainlinkSequencesStatusOracle = _chainlinkSequencesStatusOracle;

        slot0 = Slot0({
            isAmmEnabled: false,
            isSecondaryPriceEnabled: true,
            useV2Pricing: false,
            favorPrimaryPrice: false,
            priceSampleSpace: 3,
            spreadThresholdBasisPoints: 30,
            maxStrictPriceDeviation: 0
        });
    }

    function setChainlinkSequencesStatusOracle(address _chainlinkSequencesStatusOracle) external authenticate {
        chainlinkSequencesStatusOracle = _chainlinkSequencesStatusOracle;
    }

    function setAdjustment(
        address _token,
        bool _isAdditive,
        uint256 _adjustmentBps
    ) external override authenticate {
        _require(
            // solhint-disable-next-line not-rely-on-time
            lastAdjustmentTimings[_token].add(MAX_ADJUSTMENT_INTERVAL) < block.timestamp,
            Errors.PERPETUALS_VAULT_PRICE_FEED_ADJUSTMENT_FREQUENCY_EXCEEDED
        );
        _require(
            _adjustmentBps <= MAX_ADJUSTMENT_BASIS_POINTS,
            Errors.PERPETUALS_VAULT_PRICE_FEED__ADJUSTMENT_BPS_INVALID
        );
        isAdjustmentAdditive[_token] = _isAdditive;
        adjustmentBasisPoints[_token] = _adjustmentBps;
        // solhint-disable-next-line not-rely-on-time
        lastAdjustmentTimings[_token] = block.timestamp;
    }

    function setUseV2Pricing(bool _useV2Pricing) external override authenticate {
        slot0.useV2Pricing = _useV2Pricing;
    }

    function setIsAmmEnabled(bool _isEnabled) external override authenticate {
        slot0.isAmmEnabled = _isEnabled;
    }

    function setIsSecondaryPriceEnabled(bool _isEnabled) external override authenticate {
        slot0.isSecondaryPriceEnabled = _isEnabled;
    }

    function setSecondaryPriceFeed(address _secondaryPriceFeed) external authenticate {
        secondaryPriceFeed = _secondaryPriceFeed;
    }

    function setSpreadBasisPoints(address _token, uint256 _spreadBasisPoints) external override authenticate {
        _require(_spreadBasisPoints <= MAX_SPREAD_BASIS_POINTS, Errors.PERPETUALS_VAULT_PRICE_FEED__SPREAD_BPS_INVALID);
        spreadBasisPoints[_token] = _spreadBasisPoints;
    }

    function setSpreadThresholdBasisPoints(uint256 _spreadThresholdBasisPoints) external override authenticate {
        slot0.spreadThresholdBasisPoints = uint16(_spreadThresholdBasisPoints);
    }

    function setFavorPrimaryPrice(bool _favorPrimaryPrice) external override authenticate {
        slot0.favorPrimaryPrice = _favorPrimaryPrice;
    }

    function setPriceSampleSpace(uint256 _priceSampleSpace) external override authenticate {
        _require(_priceSampleSpace > 0, Errors.PERPETUALS_VAULT_PRICE_FEED__PRICE_SAMPLE_SPACE_INVALID);
        slot0.priceSampleSpace = uint8(_priceSampleSpace);
    }

    function setMaxStrictPriceDeviation(uint256 _maxStrictPriceDeviation) external override authenticate {
        slot0.maxStrictPriceDeviation = uint160(_maxStrictPriceDeviation);
    }

    function setTokenConfig(
        address _token,
        address _priceFeed,
        uint256 _priceDecimals,
        bool _isStrictStable
    ) external override authenticate {
        priceFeeds[_token] = _priceFeed;
        priceDecimals[_token] = _priceDecimals;
        strictStableTokens[_token] = _isStrictStable;
    }

    function getPrice(
        address _token,
        bool _maximise,
        bool _includeAmmPrice,
        bool /* _useSwapPricing */
    ) public view override returns (uint256) {
        uint256 price = slot0.useV2Pricing
            ? getPriceV2(_token, _maximise, _includeAmmPrice)
            : getPriceV1(_token, _maximise, _includeAmmPrice);

        uint256 adjustmentBps = adjustmentBasisPoints[_token];
        if (adjustmentBps > 0) {
            bool isAdditive = isAdjustmentAdditive[_token];
            if (isAdditive) {
                price = price.mul(BASIS_POINTS_DIVISOR.add(adjustmentBps)).div(BASIS_POINTS_DIVISOR);
            } else {
                price = price.mul(BASIS_POINTS_DIVISOR.sub(adjustmentBps)).div(BASIS_POINTS_DIVISOR);
            }
        }

        return price;
    }

    function getPriceV1(
        address _token,
        bool _maximise,
        bool _includeAmmPrice
    ) public view returns (uint256) {
        uint256 price = getPrimaryPrice(_token, _maximise);

        if (_includeAmmPrice && slot0.isAmmEnabled) {
            uint256 ammPrice = getAmmPrice(_token);
            if (ammPrice > 0) {
                if (_maximise && ammPrice > price) {
                    price = ammPrice;
                }
                if (!_maximise && ammPrice < price) {
                    price = ammPrice;
                }
            }
        }

        if (slot0.isSecondaryPriceEnabled) {
            price = getSecondaryPrice(_token, price, _maximise);
        }

        if (strictStableTokens[_token]) {
            uint256 delta = price > ONE_USD ? price.sub(ONE_USD) : ONE_USD.sub(price);
            if (delta <= slot0.maxStrictPriceDeviation) {
                return ONE_USD;
            }

            // if _maximise and price is e.g. 1.02, return 1.02
            if (_maximise && price > ONE_USD) {
                return price;
            }

            // if !_maximise and price is e.g. 0.98, return 0.98
            if (!_maximise && price < ONE_USD) {
                return price;
            }

            return ONE_USD;
        }

        uint256 _spreadBasisPoints = spreadBasisPoints[_token];

        if (_maximise) {
            return price.mul(BASIS_POINTS_DIVISOR.add(_spreadBasisPoints)).div(BASIS_POINTS_DIVISOR);
        }

        return price.mul(BASIS_POINTS_DIVISOR.sub(_spreadBasisPoints)).div(BASIS_POINTS_DIVISOR);
    }

    function getPriceV2(
        address _token,
        bool _maximise,
        bool _includeAmmPrice
    ) public view returns (uint256) {
        uint256 price = getPrimaryPrice(_token, _maximise);

        if (_includeAmmPrice && slot0.isAmmEnabled) {
            price = getAmmPriceV2(_token, _maximise, price);
        }

        if (slot0.isSecondaryPriceEnabled) {
            price = getSecondaryPrice(_token, price, _maximise);
        }

        if (strictStableTokens[_token]) {
            uint256 delta = price > ONE_USD ? price.sub(ONE_USD) : ONE_USD.sub(price);
            if (delta <= slot0.maxStrictPriceDeviation) {
                return ONE_USD;
            }

            // if _maximise and price is e.g. 1.02, return 1.02
            if (_maximise && price > ONE_USD) {
                return price;
            }

            // if !_maximise and price is e.g. 0.98, return 0.98
            if (!_maximise && price < ONE_USD) {
                return price;
            }

            return ONE_USD;
        }

        uint256 _spreadBasisPoints = spreadBasisPoints[_token];

        if (_maximise) {
            return price.mul(BASIS_POINTS_DIVISOR.add(_spreadBasisPoints)).div(BASIS_POINTS_DIVISOR);
        }

        return price.mul(BASIS_POINTS_DIVISOR.sub(_spreadBasisPoints)).div(BASIS_POINTS_DIVISOR);
    }

    function getAmmPriceV2(
        address _token,
        bool _maximise,
        uint256 _primaryPrice
    ) public view returns (uint256) {
        uint256 ammPrice = getAmmPrice(_token);
        if (ammPrice == 0) {
            return _primaryPrice;
        }

        uint256 diff = ammPrice > _primaryPrice ? ammPrice.sub(_primaryPrice) : _primaryPrice.sub(ammPrice);
        if (diff.mul(BASIS_POINTS_DIVISOR) < _primaryPrice.mul(slot0.spreadThresholdBasisPoints)) {
            if (slot0.favorPrimaryPrice) {
                return _primaryPrice;
            }
            return ammPrice;
        }

        if (_maximise && ammPrice > _primaryPrice) {
            return ammPrice;
        }

        if (!_maximise && ammPrice < _primaryPrice) {
            return ammPrice;
        }

        return _primaryPrice;
    }

    function getPrimaryPrice(address _token, bool _maximise) public view override returns (uint256) {
        address priceFeedAddress = priceFeeds[_token];
        _require(priceFeedAddress != address(0), Errors.PERPETUALS_VAULT_PRICE_FEED_PRICE_FEED_INVALID);

        if (chainlinkSequencesStatusOracle != address(0)) {
            (, int256 answer, uint256 startedAt, , ) = AggregatorV2V3Interface(chainlinkSequencesStatusOracle)
                .latestRoundData();
            // Answer == 0: Sequencer is up
            // Answer == 1: Sequencer is down
            bool isSequencerUp = answer == 0;

            if (!isSequencerUp) {
                _revert(Errors.PERPETUALS_VAULT_PRICE_FEED_CHAINLINK_SEQUENCER_OFF);
            }

            // solhint-disable-next-line not-rely-on-time
            uint256 timeSinceUp = block.timestamp - startedAt;
            if (timeSinceUp <= CHAINLINK_SEQUENCER_GRACE_PERIOD_TIME) {
                _revert(Errors.PERPETUALS_VAULT_PRICE_FEED_CHAINLINK_SEQUENCER_GRACE_PERIOD);
            }
        }

        AggregatorV2V3Interface priceFeed = AggregatorV2V3Interface(priceFeedAddress);

        uint256 price = 0;
        uint80 roundId = uint80(priceFeed.latestRound());

        for (uint80 i = 0; i < slot0.priceSampleSpace; i++) {
            if (roundId <= i) {
                break;
            }
            uint256 p;

            if (i == 0) {
                int256 _p = priceFeed.latestAnswer();
                _require(_p > 0, Errors.PERPETUALS_VAULT_PRICE_FEED_PRICE_INVALID);
                p = uint256(_p);
            } else {
                (, int256 _p, , , ) = priceFeed.getRoundData(roundId - i);
                _require(_p > 0, Errors.PERPETUALS_VAULT_PRICE_FEED_PRICE_INVALID);
                p = uint256(_p);
            }

            if (price == 0) {
                price = p;
                continue;
            }

            if (_maximise && p > price) {
                price = p;
                continue;
            }

            if (!_maximise && p < price) {
                price = p;
            }
        }

        _require(price > 0, Errors.PERPETUALS_VAULT_PRICE_FEED_FETCH_FAILED);
        // normalise price precision
        uint256 _priceDecimals = priceDecimals[_token];
        return price.mul(PRICE_PRECISION).div(10**_priceDecimals);
    }

    function getSecondaryPrice(
        address _token,
        uint256 _referencePrice,
        bool _maximise
    ) public view returns (uint256) {
        if (secondaryPriceFeed == address(0)) {
            return _referencePrice;
        }
        return IPerpetualsSecondaryPriceFeed(secondaryPriceFeed).getPrice(_token, _referencePrice, _maximise);
    }

    // solhint-disable-next-line no-unused-vars
    function getAmmPrice(address _token) public pure override returns (uint256) {
        return 0;
    }

    // if divByReserve0: calculate price as reserve1 / reserve0
    // if !divByReserve1: calculate price as reserve0 / reserve1
    function getPairPrice(address _pair, bool _divByReserve0) public view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IVelodromePair(_pair).getReserves();
        if (_divByReserve0) {
            if (reserve0 == 0) {
                return 0;
            }
            return reserve1.mul(PRICE_PRECISION).div(reserve0);
        }
        if (reserve1 == 0) {
            return 0;
        }
        return reserve0.mul(PRICE_PRECISION).div(reserve1);
    }

    function getExchangeVault() public view returns (IExchangeVault) {
        return _exchangeVault;
    }

    function _getAuthorizer() internal view returns (IAuthorizer) {
        // Access control management is delegated to the Vault's Authorizer. This lets Balancer Governance manage which
        // accounts can call permissioned functions.
        return getExchangeVault().getAuthorizer();
    }

    function _canPerform(bytes32 actionId, address account) internal view override returns (bool) {
        return _getAuthorizer().canPerform(actionId, account, address(this));
    }
}
