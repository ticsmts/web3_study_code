import { ethers } from 'ethers';

// ========== 配置 ==========
const CONFIG = {
    // L1 配置
    l1RpcUrl: process.env.SEPOLIA_RPC_URL || '<SEPOLIA_RPC_URL>',
    l1TokenAddress: process.env.L1_TOKEN || '<L1_TOKEN_ADDRESS>',

    // L2 配置（选择一个）
    l2RpcUrl: process.env.L2_RPC_URL || 'https://sepolia.optimism.io',
    l2TokenAddress: process.env.L2_TOKEN || '<L2_TOKEN_ADDRESS>',

    // 桥地址
    l1StandardBridge: process.env.L1_STANDARD_BRIDGE || '0xFBb0621E0B23b5478B630BD55a5f21f67730B0F1',

    // 跨链参数
    bridgeAmount: ethers.parseEther(process.env.BRIDGE_AMOUNT_ETH || '100'),
    minGasLimit: 200000,

    // 私钥
    privateKey: process.env.PRIVATE_KEY || '<PRIVATE_KEY>',
};

// ========== ABI ==========
const ERC20_ABI = [
    'function approve(address spender, uint256 amount) returns (bool)',
    'function balanceOf(address account) view returns (uint256)',
    'function allowance(address owner, address spender) view returns (uint256)',
    'function name() view returns (string)',
    'function symbol() view returns (string)',
];

const L1_BRIDGE_ABI = [
    'function bridgeERC20(address _localToken, address _remoteToken, uint256 _amount, uint32 _minGasLimit, bytes _extraData)',
    'function bridgeERC20To(address _localToken, address _remoteToken, address _to, uint256 _amount, uint32 _minGasLimit, bytes _extraData)',
];

// ========== 主流程 ==========
async function main() {
    console.log('='.repeat(50));
    console.log('OP Stack Standard Bridge - ERC20 跨链');
    console.log('='.repeat(50));

    // 连接 L1
    const l1Provider = new ethers.JsonRpcProvider(CONFIG.l1RpcUrl);
    const wallet = new ethers.Wallet(CONFIG.privateKey, l1Provider);

    console.log(`\n钱包地址: ${wallet.address}`);

    // 合约实例
    const l1Token = new ethers.Contract(CONFIG.l1TokenAddress, ERC20_ABI, wallet);
    const l1Bridge = new ethers.Contract(CONFIG.l1StandardBridge, L1_BRIDGE_ABI, wallet);

    // 获取 Token 信息
    const tokenName = await l1Token.name();
    const tokenSymbol = await l1Token.symbol();
    console.log(`L1 Token: ${tokenName} (${tokenSymbol})`);
    console.log(`L1 Token 地址: ${CONFIG.l1TokenAddress}`);
    console.log(`L2 Token 地址: ${CONFIG.l2TokenAddress}`);

    // Step 1: 检查余额
    const balance = await l1Token.balanceOf(wallet.address);
    console.log(`\nL1 Token 余额: ${ethers.formatEther(balance)} ${tokenSymbol}`);
    console.log(`计划跨链数量: ${ethers.formatEther(CONFIG.bridgeAmount)} ${tokenSymbol}`);

    if (balance < CONFIG.bridgeAmount) {
        throw new Error(`余额不足！当前: ${ethers.formatEther(balance)}, 需要: ${ethers.formatEther(CONFIG.bridgeAmount)}`);
    }

    // Step 2: Approve
    console.log('\n[Step 2] 正在授权 L1StandardBridge...');
    const approveTx = await l1Token.approve(CONFIG.l1StandardBridge, CONFIG.bridgeAmount);
    console.log(`Approve TX: ${approveTx.hash}`);
    await approveTx.wait();
    console.log('✅ 授权成功!');

    // 验证授权
    const allowance = await l1Token.allowance(wallet.address, CONFIG.l1StandardBridge);
    console.log(`当前授权额度: ${ethers.formatEther(allowance)} ${tokenSymbol}`);

    // Step 3: Bridge
    console.log('\n[Step 3] 正在发起跨链...');
    const bridgeTx = await l1Bridge.bridgeERC20(
        CONFIG.l1TokenAddress,
        CONFIG.l2TokenAddress,
        CONFIG.bridgeAmount,
        CONFIG.minGasLimit,
        '0x'
    );
    console.log(`Bridge TX: ${bridgeTx.hash}`);
    await bridgeTx.wait();
    console.log('✅ 跨链交易已提交!');

    // Step 4: 等待并验证 L2 余额
    console.log('\n[Step 4] 等待跨链完成 (1-5 分钟)...');
    console.log('开始轮询 L2 余额...\n');

    const l2Provider = new ethers.JsonRpcProvider(CONFIG.l2RpcUrl);
    const l2Token = new ethers.Contract(CONFIG.l2TokenAddress, ERC20_ABI, l2Provider);

    const startBalance = await l2Token.balanceOf(wallet.address);
    console.log(`L2 初始余额: ${ethers.formatEther(startBalance)}`);

    // 轮询 30 次，每次间隔 10 秒
    for (let i = 0; i < 30; i++) {
        const l2Balance = await l2Token.balanceOf(wallet.address);
        const elapsed = (i + 1) * 10;
        console.log(`[${elapsed}s] L2 余额: ${ethers.formatEther(l2Balance)}`);

        if (l2Balance > startBalance) {
            console.log('\n' + '='.repeat(50));
            console.log('✅ 跨链成功!');
            console.log('='.repeat(50));
            console.log(`\n最终 L2 余额: ${ethers.formatEther(l2Balance)} ${tokenSymbol}`);
            return;
        }

        await new Promise(r => setTimeout(r, 10000));
    }

    console.log('\n⏳ 超时，请稍后手动检查 L2 余额');
}

main().catch(console.error);
