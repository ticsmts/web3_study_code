import { keccak256, encodePacked, Address } from 'viem';

/**
 * Merkle Tree 工具类
 * 用于生成和验证白名单 Merkle 证明
 */

// 计算叶子节点哈希
export function computeLeaf(address: Address): `0x${string}` {
    return keccak256(encodePacked(['address'], [address]));
}

// 排序并哈希两个节点
function hashPair(a: `0x${string}`, b: `0x${string}`): `0x${string}` {
    // 确保较小的哈希在前面，保证一致性
    const [left, right] = a < b ? [a, b] : [b, a];
    return keccak256(encodePacked(['bytes32', 'bytes32'], [left, right]));
}

/**
 * 构建 Merkle 树
 * @param addresses 白名单地址列表
 * @returns { root, leaves, layers }
 */
export function buildMerkleTree(addresses: Address[]): {
    root: `0x${string}`;
    leaves: `0x${string}`[];
    layers: `0x${string}`[][];
} {
    if (addresses.length === 0) {
        return {
            root: '0x0000000000000000000000000000000000000000000000000000000000000000',
            leaves: [],
            layers: [],
        };
    }

    // 计算所有叶子节点
    const leaves = addresses.map(addr => computeLeaf(addr as Address));

    // 排序叶子节点（可选，但有助于一致性）
    const sortedLeaves = [...leaves].sort();

    // 构建树的各层
    const layers: `0x${string}`[][] = [sortedLeaves];

    let currentLayer = sortedLeaves;
    while (currentLayer.length > 1) {
        const nextLayer: `0x${string}`[] = [];
        for (let i = 0; i < currentLayer.length; i += 2) {
            if (i + 1 < currentLayer.length) {
                nextLayer.push(hashPair(currentLayer[i], currentLayer[i + 1]));
            } else {
                // 奇数个节点时，最后一个节点自己与自己配对
                nextLayer.push(hashPair(currentLayer[i], currentLayer[i]));
            }
        }
        layers.push(nextLayer);
        currentLayer = nextLayer;
    }

    return {
        root: currentLayer[0],
        leaves: sortedLeaves,
        layers,
    };
}

/**
 * 获取地址的 Merkle 证明
 * @param addresses 完整的白名单地址列表
 * @param targetAddress 要获取证明的地址
 * @returns Merkle 证明数组
 */
export function getMerkleProof(
    addresses: Address[],
    targetAddress: Address
): `0x${string}`[] {
    const { leaves, layers } = buildMerkleTree(addresses);
    const targetLeaf = computeLeaf(targetAddress);

    let index = leaves.indexOf(targetLeaf);
    if (index === -1) {
        return []; // 地址不在白名单中
    }

    const proof: `0x${string}`[] = [];

    for (let i = 0; i < layers.length - 1; i++) {
        const layer = layers[i];
        const isRightNode = index % 2 === 1;
        const siblingIndex = isRightNode ? index - 1 : index + 1;

        if (siblingIndex < layer.length) {
            proof.push(layer[siblingIndex]);
        } else {
            // 如果没有兄弟节点，使用自己
            proof.push(layer[index]);
        }

        index = Math.floor(index / 2);
    }

    return proof;
}

/**
 * 验证 Merkle 证明
 * @param proof Merkle 证明
 * @param root Merkle 根
 * @param leaf 叶子节点
 * @returns 是否验证通过
 */
export function verifyMerkleProof(
    proof: `0x${string}`[],
    root: `0x${string}`,
    leaf: `0x${string}`
): boolean {
    let computedHash = leaf;

    for (const proofElement of proof) {
        computedHash = hashPair(computedHash, proofElement);
    }

    return computedHash === root;
}

/**
 * 验证地址是否在白名单中
 * @param addresses 完整白名单
 * @param targetAddress 目标地址
 * @param proof Merkle 证明
 * @param root Merkle 根
 */
export function isAddressWhitelisted(
    targetAddress: Address,
    proof: `0x${string}`[],
    root: `0x${string}`
): boolean {
    const leaf = computeLeaf(targetAddress);
    return verifyMerkleProof(proof, root, leaf);
}

// 默认导出一个简单的单地址 root 计算（用于测试）
export function computeSingleAddressRoot(address: Address): `0x${string}` {
    return computeLeaf(address);
}
