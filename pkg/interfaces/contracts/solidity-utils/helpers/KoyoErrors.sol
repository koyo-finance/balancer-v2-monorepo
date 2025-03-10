// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;

// solhint-disable

/**
 * @dev Reverts if `condition` is false, with a revert reason containing `errorCode`. Only codes up to 999 are
 * supported.
 */
function _require(bool condition, uint256 errorCode) pure {
    if (!condition) _revert(errorCode);
}

/**
 * @dev Reverts with a revert reason containing `errorCode`. Only codes up to 999 are supported.
 */
function _revert(uint256 errorCode) pure {
    // We're going to dynamically create a revert string based on the error code, with the following format:
    // 'KYO#{errorCode}'
    // where the code is left-padded with zeroes to three digits (so they range from 000 to 99999).
    //
    // We don't have revert strings embedded in the contract to save bytecode size: it takes much less space to store a
    // number (8 to 16 bits) than the individual string characters.
    //
    // The dynamic string creation algorithm that follows could be implemented in Solidity, but assembly allows for a
    // much denser implementation, again saving bytecode size. Given this function unconditionally reverts, this is a
    // safe place to rely on it without worrying about how its usage might affect e.g. memory contents.
    assembly {
        // First, we need to compute the ASCII representation of the error code. We assume that it is in the 0-99999
        // range, so we only need to convert five digits. To convert the digits to ASCII, we add 0x30, the value for
        // the '0' character.

        let units := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let tenths := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let hundreds := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let thousands := add(mod(errorCode, 10), 0x30)

        errorCode := div(errorCode, 10)
        let tenThousands := add(mod(errorCode, 10), 0x30)

        // With the individual characters, we can now construct the full string. The "KYO#" part is a known constant
        // (0x42414c23): we simply shift this by 24 (to provide space for the 3 bytes of the error code), and add the
        // characters to it, each shifted by a multiple of 8.
        // The revert reason is then shifted left by 184 bits (256 minus the length of the string, 9 characters * 8 bits
        // per character = 56) to locate it in the most significant part of the 256 slot (the beginning of a byte
        // array).

        let revertReason := shl(
            184,
            add(
                0x4b594f23000000,
                add(add(add(add(units, shl(8, tenths)), shl(16, hundreds)), shl(24, thousands)), shl(32, tenThousands))
            )
        )

        // We can now encode the reason in memory, which can be safely overwritten as we're about to revert. The encoded
        // message will have the following layout:
        // [ revert reason identifier ] [ string location offset ] [ string length ] [ string contents ]
        //              4                           32                      32                 32

        // The Solidity revert reason identifier is 0x08c739a0, the function selector of the Error(string) function. We
        // also write zeroes to the next 28 bytes of memory, but those are about to be overwritten.
        mstore(0x0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        // Next is the offset to the location of the string, which will be placed immediately after (20 bytes away).
        mstore(0x04, 0x0000000000000000000000000000000000000000000000000000000000000020)
        // The string length is fixed: 9 characters.
        mstore(0x24, 9)
        // Finally, the string itself is stored.
        mstore(0x44, revertReason)

        // Even if the string is only 9 bytes long, we need to return a full 32 byte slot containing it. The length of
        // the encoded message is therefore 4 + 32 + 32 + 32 = 100.
        revert(0, 100)
    }
}

library Errors {
    // Math
    uint256 internal constant ADD_OVERFLOW = 0;
    uint256 internal constant SUB_OVERFLOW = 1;
    uint256 internal constant SUB_UNDERFLOW = 2;
    uint256 internal constant MUL_OVERFLOW = 3;
    uint256 internal constant ZERO_DIVISION = 4;
    uint256 internal constant DIV_INTERNAL = 5;
    uint256 internal constant X_OUT_OF_BOUNDS = 6;
    uint256 internal constant Y_OUT_OF_BOUNDS = 7;
    uint256 internal constant PRODUCT_OUT_OF_BOUNDS = 8;
    uint256 internal constant INVALID_EXPONENT = 9;

    // Input
    uint256 internal constant OUT_OF_BOUNDS = 100;
    uint256 internal constant UNSORTED_ARRAY = 101;
    uint256 internal constant UNSORTED_TOKENS = 102;
    uint256 internal constant INPUT_LENGTH_MISMATCH = 103;
    uint256 internal constant ZERO_TOKEN = 104;
    uint256 internal constant INPUT_LENGTH_INSUFFICIENT = 105;

    // Shared pools
    uint256 internal constant MIN_TOKENS = 200;
    uint256 internal constant MAX_TOKENS = 201;
    uint256 internal constant MAX_SWAP_FEE_PERCENTAGE = 202;
    uint256 internal constant MIN_SWAP_FEE_PERCENTAGE = 203;
    uint256 internal constant MINIMUM_BPT = 204;
    uint256 internal constant CALLER_NOT_VAULT = 205;
    uint256 internal constant UNINITIALIZED = 206;
    uint256 internal constant BPT_IN_MAX_AMOUNT = 207;
    uint256 internal constant BPT_OUT_MIN_AMOUNT = 208;
    uint256 internal constant EXPIRED_PERMIT = 209;
    uint256 internal constant NOT_TWO_TOKENS = 210;
    uint256 internal constant DISABLED = 211;

    // Pools
    uint256 internal constant MIN_AMP = 300;
    uint256 internal constant MAX_AMP = 301;
    uint256 internal constant MIN_WEIGHT = 302;
    uint256 internal constant MAX_STABLE_TOKENS = 303;
    uint256 internal constant MAX_IN_RATIO = 304;
    uint256 internal constant MAX_OUT_RATIO = 305;
    uint256 internal constant MIN_BPT_IN_FOR_TOKEN_OUT = 306;
    uint256 internal constant MAX_OUT_BPT_FOR_TOKEN_IN = 307;
    uint256 internal constant NORMALIZED_WEIGHT_INVARIANT = 308;
    uint256 internal constant INVALID_TOKEN = 309;
    uint256 internal constant UNHANDLED_JOIN_KIND = 310;
    uint256 internal constant ZERO_INVARIANT = 311;
    uint256 internal constant ORACLE_INVALID_SECONDS_QUERY = 312;
    uint256 internal constant ORACLE_NOT_INITIALIZED = 313;
    uint256 internal constant ORACLE_QUERY_TOO_OLD = 314;
    uint256 internal constant ORACLE_INVALID_INDEX = 315;
    uint256 internal constant ORACLE_BAD_SECS = 316;
    uint256 internal constant AMP_END_TIME_TOO_CLOSE = 317;
    uint256 internal constant AMP_ONGOING_UPDATE = 318;
    uint256 internal constant AMP_RATE_TOO_HIGH = 319;
    uint256 internal constant AMP_NO_ONGOING_UPDATE = 320;
    uint256 internal constant STABLE_INVARIANT_DIDNT_CONVERGE = 321;
    uint256 internal constant STABLE_GET_BALANCE_DIDNT_CONVERGE = 322;
    uint256 internal constant RELAYER_NOT_CONTRACT = 323;
    uint256 internal constant BASE_POOL_RELAYER_NOT_CALLED = 324;
    uint256 internal constant REBALANCING_RELAYER_REENTERED = 325;
    uint256 internal constant GRADUAL_UPDATE_TIME_TRAVEL = 326;
    uint256 internal constant SWAPS_DISABLED = 327;
    uint256 internal constant CALLER_IS_NOT_LBP_OWNER = 328;
    uint256 internal constant PRICE_RATE_OVERFLOW = 329;
    uint256 internal constant INVALID_JOIN_EXIT_KIND_WHILE_SWAPS_DISABLED = 330;
    uint256 internal constant WEIGHT_CHANGE_TOO_FAST = 331;
    uint256 internal constant LOWER_GREATER_THAN_UPPER_TARGET = 332;
    uint256 internal constant UPPER_TARGET_TOO_HIGH = 333;
    uint256 internal constant UNHANDLED_BY_LINEAR_POOL = 334;
    uint256 internal constant OUT_OF_TARGET_RANGE = 335;
    uint256 internal constant UNHANDLED_EXIT_KIND = 336;
    uint256 internal constant UNAUTHORIZED_EXIT = 337;
    uint256 internal constant MAX_MANAGEMENT_SWAP_FEE_PERCENTAGE = 338;
    uint256 internal constant UNHANDLED_BY_MANAGED_POOL = 339;
    uint256 internal constant UNHANDLED_BY_PHANTOM_POOL = 340;
    uint256 internal constant TOKEN_DOES_NOT_HAVE_RATE_PROVIDER = 341;
    uint256 internal constant INVALID_INITIALIZATION = 342;
    uint256 internal constant OUT_OF_NEW_TARGET_RANGE = 343;
    uint256 internal constant UNAUTHORIZED_OPERATION = 344;
    uint256 internal constant UNINITIALIZED_POOL_CONTROLLER = 345;
    uint256 internal constant SET_SWAP_FEE_DURING_FEE_CHANGE = 346;
    uint256 internal constant SET_SWAP_FEE_PENDING_FEE_CHANGE = 347;
    uint256 internal constant CHANGE_TOKENS_DURING_WEIGHT_CHANGE = 348;
    uint256 internal constant CHANGE_TOKENS_PENDING_WEIGHT_CHANGE = 349;
    uint256 internal constant MAX_WEIGHT = 350;
    uint256 internal constant UNAUTHORIZED_JOIN = 351;
    uint256 internal constant MAX_MANAGEMENT_AUM_FEE_PERCENTAGE = 352;

    // Lib
    uint256 internal constant REENTRANCY = 400;
    uint256 internal constant SENDER_NOT_ALLOWED = 401;
    uint256 internal constant PAUSED = 402;
    uint256 internal constant PAUSE_WINDOW_EXPIRED = 403;
    uint256 internal constant MAX_PAUSE_WINDOW_DURATION = 404;
    uint256 internal constant MAX_BUFFER_PERIOD_DURATION = 405;
    uint256 internal constant INSUFFICIENT_BALANCE = 406;
    uint256 internal constant INSUFFICIENT_ALLOWANCE = 407;
    uint256 internal constant ERC20_TRANSFER_FROM_ZERO_ADDRESS = 408;
    uint256 internal constant ERC20_TRANSFER_TO_ZERO_ADDRESS = 409;
    uint256 internal constant ERC20_MINT_TO_ZERO_ADDRESS = 410;
    uint256 internal constant ERC20_BURN_FROM_ZERO_ADDRESS = 411;
    uint256 internal constant ERC20_APPROVE_FROM_ZERO_ADDRESS = 412;
    uint256 internal constant ERC20_APPROVE_TO_ZERO_ADDRESS = 413;
    uint256 internal constant ERC20_TRANSFER_EXCEEDS_ALLOWANCE = 414;
    uint256 internal constant ERC20_DECREASED_ALLOWANCE_BELOW_ZERO = 415;
    uint256 internal constant ERC20_TRANSFER_EXCEEDS_BALANCE = 416;
    uint256 internal constant ERC20_BURN_EXCEEDS_ALLOWANCE = 417;
    uint256 internal constant SAFE_ERC20_CALL_FAILED = 418;
    uint256 internal constant ADDRESS_INSUFFICIENT_BALANCE = 419;
    uint256 internal constant ADDRESS_CANNOT_SEND_VALUE = 420;
    uint256 internal constant SAFE_CAST_VALUE_CANT_FIT_INT256 = 421;
    uint256 internal constant GRANT_SENDER_NOT_ADMIN = 422;
    uint256 internal constant REVOKE_SENDER_NOT_ADMIN = 423;
    uint256 internal constant RENOUNCE_SENDER_NOT_ALLOWED = 424;
    uint256 internal constant BUFFER_PERIOD_EXPIRED = 425;
    uint256 internal constant CALLER_IS_NOT_OWNER = 426;
    uint256 internal constant NEW_OWNER_IS_ZERO = 427;
    uint256 internal constant CODE_DEPLOYMENT_FAILED = 428;
    uint256 internal constant CALL_TO_NON_CONTRACT = 429;
    uint256 internal constant LOW_LEVEL_CALL_FAILED = 430;
    uint256 internal constant NOT_PAUSED = 431;
    uint256 internal constant ADDRESS_ALREADY_ALLOWLISTED = 432;
    uint256 internal constant ADDRESS_NOT_ALLOWLISTED = 433;
    uint256 internal constant ERC20_BURN_EXCEEDS_BALANCE = 434;
    uint256 internal constant INVALID_OPERATION = 435;
    uint256 internal constant CODEC_OVERFLOW = 436;
    uint256 internal constant IN_RECOVERY_MODE = 437;
    uint256 internal constant NOT_IN_RECOVERY_MODE = 438;
    uint256 internal constant INDUCED_FAILURE = 439;
    uint256 internal constant ERC721_INVALID_OWNER_ADDRESS_ZERO = 440;
    uint256 internal constant ERC721_INVALID_TOKEN_ID = 441;
    uint256 internal constant ERC721_APPROVAL_TO_CURRENT_OWNER = 442;
    uint256 internal constant ERC721_APPROVE_CALLER_NOT_AUTHORISED = 443;
    uint256 internal constant ERC721_TRANSFER_TO_NON_RECEIVER_IMPLEMENTER = 444;
    uint256 internal constant ERC721_MINT_TO_ZERO_ADDRESS = 445;
    uint256 internal constant ERC721_ALREADY_MINTED = 446;
    uint256 internal constant ERC721_TRANSFER_FROM_INCORRECT_OWNER = 447;
    uint256 internal constant ERC721_TRANSFER_TO_ADDRESS_ZERO = 448;
    uint256 internal constant ERC721_APPROVE_TO_CALLER = 449;

    // Vault
    uint256 internal constant INVALID_POOL_ID = 500;
    uint256 internal constant CALLER_NOT_POOL = 501;
    uint256 internal constant SENDER_NOT_ASSET_MANAGER = 502;
    uint256 internal constant USER_DOESNT_ALLOW_RELAYER = 503;
    uint256 internal constant INVALID_SIGNATURE = 504;
    uint256 internal constant EXIT_BELOW_MIN = 505;
    uint256 internal constant JOIN_ABOVE_MAX = 506;
    uint256 internal constant SWAP_LIMIT = 507;
    uint256 internal constant SWAP_DEADLINE = 508;
    uint256 internal constant CANNOT_SWAP_SAME_TOKEN = 509;
    uint256 internal constant UNKNOWN_AMOUNT_IN_FIRST_SWAP = 510;
    uint256 internal constant MALCONSTRUCTED_MULTIHOP_SWAP = 511;
    uint256 internal constant INTERNAL_BALANCE_OVERFLOW = 512;
    uint256 internal constant INSUFFICIENT_INTERNAL_BALANCE = 513;
    uint256 internal constant INVALID_ETH_INTERNAL_BALANCE = 514;
    uint256 internal constant INVALID_POST_LOAN_BALANCE = 515;
    uint256 internal constant INSUFFICIENT_ETH = 516;
    uint256 internal constant UNALLOCATED_ETH = 517;
    uint256 internal constant ETH_TRANSFER = 518;
    uint256 internal constant CANNOT_USE_ETH_SENTINEL = 519;
    uint256 internal constant TOKENS_MISMATCH = 520;
    uint256 internal constant TOKEN_NOT_REGISTERED = 521;
    uint256 internal constant TOKEN_ALREADY_REGISTERED = 522;
    uint256 internal constant TOKENS_ALREADY_SET = 523;
    uint256 internal constant TOKENS_LENGTH_MUST_BE_2 = 524;
    uint256 internal constant NONZERO_TOKEN_BALANCE = 525;
    uint256 internal constant BALANCE_TOTAL_OVERFLOW = 526;
    uint256 internal constant POOL_NO_TOKENS = 527;
    uint256 internal constant INSUFFICIENT_FLASH_LOAN_BALANCE = 528;

    // Fees
    uint256 internal constant SWAP_FEE_PERCENTAGE_TOO_HIGH = 600;
    uint256 internal constant FLASH_LOAN_FEE_PERCENTAGE_TOO_HIGH = 601;
    uint256 internal constant INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT = 602;
    uint256 internal constant AUM_FEE_PERCENTAGE_TOO_HIGH = 603;

    // Perpetuals
    // Perpetuals - Vault
    uint256 internal constant VAULT_POOL_AMOUNT_EXCEEDED = 10101;
    uint256 internal constant VAULT_INSUFFICIENT_RESERVE = 10102;

    uint256 internal constant VAULT_ZERO_ERROR = 10201;
    uint256 internal constant VAULT_ALREADY_INITIALIZED = 10202;
    uint256 internal constant VAULT__MAX_LEVERAGE_INVALID = 10203;
    uint256 internal constant VAULT__TAX_BASIS_POINTS_INVALID = 10204;
    uint256 internal constant VAULT__STABLE_TAX_BASIS_POINTS_INVALID = 10205;
    uint256 internal constant VAULT__MINT_BURN_FEE_BASIS_POINTS_INVALID = 10206;
    uint256 internal constant VAULT__SWAP_FEE_BASIS_POINTS_INVALID = 10207;
    uint256 internal constant VAULT__STABLE_SWAP_FEE_BASIS_POINTS_INVALID = 10208;
    uint256 internal constant VAULT__MARGIN_FEE_BASIS_POINTS_INVALID = 10209;
    uint256 internal constant VAULT__LIQUIDATION_FEE_USD_INVALID = 10210;
    uint256 internal constant VAULT__FUNDING_INTERVAL_INVALID = 10211;
    uint256 internal constant VAULT__FUNDING_RATE_FACTOR_INVALID = 10212;
    uint256 internal constant VAULT__STABLE_FUNDING_RATE_FACTOR_INVALID = 10213;
    uint256 internal constant VAULT__AVERAGE_PRICE_INVALID = 10214;
    uint256 internal constant VAULT_TOKEN_AMOUNT_INVALID = 10215;
    uint256 internal constant VAULT_USDK_AMOUNT_INVALID = 10216;
    uint256 internal constant VAULT_REDEMPTION_AMOUNT_INVALID = 10217;
    uint256 internal constant VAULT_AMOUNT_OUT_INVALID = 10218;
    uint256 internal constant VAULT_AMOUNT_IN_INVALID = 10219;
    uint256 internal constant VAULT_TOKENS_INVALID = 10220;
    uint256 internal constant VAULT_POSITION_SIZE_INVALID = 10221;
    uint256 internal constant VAULT_LIQUIDATOR_INVALID = 10222;
    uint256 internal constant VAULT_POSITION_INVALID = 10223;
    uint256 internal constant VAULT_MESSAGE_SENDER_INVALID = 10224;
    uint256 internal constant VAULT_INCREASE_INVALID = 10225;

    uint256 internal constant VAULT__TOKEN_NOT_WHITELISTED = 10226;
    uint256 internal constant VAULT__TOKEN_IN_NOT_WHITELISTED = 10227;
    uint256 internal constant VAULT__TOKEN_OUT_NOT_WHITELISTED = 10228;
    uint256 internal constant VAULT__COLLATERAL_TOKEN_NOT_WHITELISTED = 10229;
    uint256 internal constant VAULT_TOKEN_NOT_WHITELISTED = 10230;

    uint256 internal constant VAULT_SWAPS_NOT_ENABLED = 10231;
    uint256 internal constant VAULT_LEVERAGE_NOT_ENABLED = 10232;

    uint256 internal constant VAULT_POSITION_SIZE_EXCEEDED = 10233;
    uint256 internal constant VAULT_POSITION_COLLATERAL_EXCEEDED = 10234;
    uint256 internal constant VAULT_MAX_USDK_EXCEEDED = 10235;
    uint256 internal constant VAULT_MAX_GAS_PRICE_EXCEEDED = 10236;
    uint256 internal constant VAULT_MAX_SHORTS_EXCEEDED = 10237;

    uint256 internal constant VAULT_POSITION_EMPTY = 10238;
    uint256 internal constant VAULT_POSITION_CANNOT_LIQUIDATE = 10239;

    uint256 internal constant VAULT_TOKENS_MISSMATCHED = 10240;

    uint256 internal constant VAULT_COLLATERAL_INSUFFICIENT_FOR_FEES = 10241;
    uint256 internal constant VAULT_COLLATERAL_SHOULD_WITHDRAW = 10242;
    uint256 internal constant VAULT__COLLATERAL_SMALLER_THAN__SIZE = 10243;
    uint256 internal constant VAULT__COLLATERAL_TOKEN_A_STABLE_TOKEN = 10244;
    uint256 internal constant VAULT__COLLATERAL_TOKEN_NOT_A_STABLE_TOKEN = 10245;

    uint256 internal constant VAULT__INDEX_TOKEN_A_STABLE_TOKEN = 10246;
    uint256 internal constant VAULT__INDEX_TOKEN_NOT_SHORTABLE = 10247;

    uint256 internal constant VAULT_RESERVE_EXCEEDS_POOL = 10248;
    uint256 internal constant VAULT_FORBIDDEN = 10249;

    // Perpetuals - Vault; Router
    uint256 internal constant PERPETUALS_VAULT_ROUTER_SENDER_NOT_W_NATIVE = 10401;
    uint256 internal constant PERPETUALS_VAULT_ROUTER_PLUGIN_INVALID = 10402;
    uint256 internal constant PERPETUALS_VAULT_ROUTER_PLUGIN_NOT_APPROVED = 10403;
    uint256 internal constant PERPETUALS_VAULT_ROUTER__PATH_INVALID = 10404;
    uint256 internal constant PERPETUALS_VAULT_ROUTER__PATH_LENGTH_INVALID = 10405;
    uint256 internal constant PERPETUALS_VAULT_ROUTER_AMOUNT_OUT_INSUFFICIENT = 10406;
    uint256 internal constant PERPETUALS_VAULT_ROUTER_MARK_PRICE_LOWER_LIMIT = 10407;
    uint256 internal constant PERPETUALS_VAULT_ROUTER_MARK_PRICE_HIGHER_LIMIT = 10408;

    // Perpetuals - External authorization
    uint256 internal constant PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_VAULT_CALL_REVERTED = 10301;
    uint256 internal constant PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_PRICE_FEED_CALL_REVERTED = 10302;
    uint256 internal constant PERPETUALS_EXTERNAL_AUTHORIZATION_ARBITRARY_DISSALOWED_TARGET_ADDRESS = 10303;

    // Perpetuals - KPLP Manager
    uint256 internal constant KPLP_MANAGER_ACTION_NOT_ENABLED = 10501;
    uint256 internal constant KPLP_MANAGER__AMOUNT_INVALID = 10502;
    uint256 internal constant KPLP_MANAGER__KPLP_AMOUNT_INVALID = 10503;
    uint256 internal constant KPLP_MANAGER__COOLDOWN_DURATION_INVALID = 10504;
    uint256 internal constant KPLP_MANAGER_USDK_OUTPUT_INSUFFICIENT = 10505;
    uint256 internal constant KPLP_MANAGER_KPLP_OUTPUT_INSUFFICIENT = 10506;
    uint256 internal constant KPLP_MANAGER_OUTPUT_INSUFFICIENT = 10507;
    uint256 internal constant KPLP_MANAGER_COOLDOWN_NOT_PASSED = 10508;
    uint256 internal constant KPLP_MANAGER_CALLER_NOT_HANDLER = 10509;

    // Perpetuals - Vault price feed
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED__ADJUSTMENT_BPS_INVALID = 10601;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED__SPREAD_BPS_INVALID = 10602;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED__PRICE_SAMPLE_SPACE_INVALID = 10603;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED_PRICE_FEED_INVALID = 10604;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED_PRICE_INVALID = 10605;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED_ADJUSTMENT_FREQUENCY_EXCEEDED = 10606;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED_CHAINLINK_SEQUENCER_OFF = 10607;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED_CHAINLINK_SEQUENCER_GRACE_PERIOD = 10608;
    uint256 internal constant PERPETUALS_VAULT_PRICE_FEED_FETCH_FAILED = 10609;

    // Perpetuals - Vault utils
    uint256 internal constant PERPETUALS_VAULT_UTILS_LEVERAGE_LOW = 10701;
    uint256 internal constant PERPETUALS_VAULT_UTILS_WITHDRAWAL_COOLDOWN_DURATION_MAX = 10702;
    uint256 internal constant PERPETUALS_VAULT_UTILS_COOLDOWN_DURATION_NOT_PASSED = 10703;
    uint256 internal constant PERPETUALS_VAULT_UTILS_MIN_LEVERAGE_CAP_EXCEEDED = 10704;
    uint256 internal constant PERPETUALS_VAULT_UTILS_LOSSES_COLLATERAL_EXCEED = 10705;
    uint256 internal constant PERPETUALS_VAULT_UTILS_FEES_COLLATERAL_EXCEED = 10706;
    uint256 internal constant PERPETUALS_VAULT_UTILS_LIQUIDATION_FEES_COLLATERAL_EXCEED = 10707;
    uint256 internal constant PERPETUALS_VAULT_UTILS_MAX_LEVERAGE_EXCEEDED = 10708;
}
