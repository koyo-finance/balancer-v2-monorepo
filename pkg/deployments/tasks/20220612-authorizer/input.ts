import { Network } from '../../src/types';

export interface AuthorizerDeployment {
  admin: string;
}

const input: { [network in Network]: AuthorizerDeployment } = {
  boba: {
    admin: '0xC4d54E7e94B68d88Ad7b00d0689669d520cce2fB',
  },
  aurora: {
    admin: '0xC4d54E7e94B68d88Ad7b00d0689669d520cce2fB',
  },
};

export default input;
