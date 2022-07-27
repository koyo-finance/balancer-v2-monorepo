import { Network } from '../../src/types';

export interface AllowListAuthenticationDeployment {
  proxyAdmin: string;
}

const input: { [network in Network]: AllowListAuthenticationDeployment } = {
  boba: {
    proxyAdmin: '0xC4d54E7e94B68d88Ad7b00d0689669d520cce2fB',
  },
};

export default input;
