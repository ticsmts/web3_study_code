// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UQ112x112
 * @notice UQ112.112 定点数格式库 UQ112.112 fixed-point number format library
 * @dev 用于价格表示，防止精度损失 Used for price representation to prevent precision loss
 *
 * 格式说明 Format Explanation:
 * - UQ112.112 = 无符号定点数，112位整数部分 + 112位小数部分
 * - UQ112.112 = Unsigned fixed-point, 112-bit integer + 112-bit fractional
 * - 范围: [0, 2^112 - 1], 精度: 1/2^112
 * - Range: [0, 2^112 - 1], Precision: 1/2^112
 * - 存储在uint224中 / Stored in uint224
 */
library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    /**
     * @notice 将uint112编码为UQ112.112格式
     * @notice Encode uint112 to UQ112.112 format
     * @param y 输入数值 Input value
     * @return z UQ112.112格式的结果 Result in UQ112.112 format
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // y * 2^112
    }

    /**
     * @notice UQ112.112格式的除法 Division in UQ112.112 format
     * @dev 计算 x / y，结果为UQ112.112格式
     * @dev Calculate x / y, result in UQ112.112 format
     * @param x 被除数(UQ112.112格式) Dividend (UQ112.112 format)
     * @param y 除数(uint112) Divisor (uint112)
     * @return z 商(UQ112.112格式) Quotient (UQ112.112 format)
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
