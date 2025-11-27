#encoding=utf-8
import base64
import hashlib
import time
import argparse

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives import hashes, serialization

'''
实践非对称加密 RSA：

先生成一个公私钥对
用私钥对符合 POW 4 个 0 开头的哈希值的 “昵称 + nonce” 进行私钥签名
用公钥验证
'''
def mine(nickname, zero_count):
    '''
     挖矿函数：找到一个nonce值，使其可以满足sha256(nickname+zero_count*0)的值满足前置0难度要求
    :param nickname: 昵称
    :param zero_count: 挖矿难度，哈希值的前置0数量
    :return: 挖矿成功，返回nonce, nickname+nonce, 哈希值，挖矿所用时间
    '''
    nonce = 0 
    prefix_zeros = zero_count * "0"
    start = time.perf_counter()

    while True:
        text = f"{nickname}{nonce}"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if h.startswith(prefix_zeros):
            end = time.perf_counter()
            use_time = end - start
            return nonce, text, h, use_time
        nonce += 1

#生成公私钥对
def generate_keypair(key_size=2048):
    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=key_size)
    public_key = private_key.public_key()
    return private_key, public_key

# 私钥签名
def sign_message(private_key, message):
    signature = private_key.sign(
        message,
        padding.PSS(
            mgf=padding.MGF1(algorithm=hashes.SHA256()),
            salt_length=padding.PSS.MAX_LENGTH
        ),
        hashes.SHA256()
    )
    return signature

# 公钥验证
def verify_message(public_key, signature, message):
    try:
        public_key.verify(
            signature,
            message,
            padding.PSS(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                salt_length=padding.PSS.MAX_LENGTH,
            ),
            hashes.SHA256()
        )
        return True
    except InvalidSignature:
        return False

def run():
    parser = argparse.ArgumentParser(description="POW+RSA签名实践")
    parser.add_argument("--name", type=str, default="ticsmts", help="用于工作量证明的昵称")
    parser.add_argument("--zeros", type=int, default=4, help="哈希值的前置0数量")

    args = parser.parse_args()
    if args.zeros <= 0:
        parser.error("--zeros 必须为正整数")
    
    # 1. 首先挖矿，挖出符合4个0开头的哈希值的“昵称 + nonce”字符串
    nonce, text, h, use_time = mine(args.name, args.zeros)
    print(f"耗时: {use_time:.6f} 秒")
    print(f"Hash 内容: {text}")
    print(f"Hash 值:   {h}")
    print(f"nonce:     {nonce}")
    print()

    # 2. 生成公私钥对
    print("生成公私钥对：")
    private_key, public_key = generate_keypair()

    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),  # 不加密码
    )
    public_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    print("==== 私钥 ====")
    print("\n".join(private_pem.decode("utf-8").splitlines()))
    print()

    print("==== 公钥（PEM） ====")
    print(public_pem.decode("utf-8"))
    print()

    # 3. 使用私钥对字符串进行ras 签名
    message = text.encode("utf-8")
    signature = sign_message(private_key, message)
    signature_b64 = base64.b64encode(signature).decode("utf-8")

    print("==== 签名结果 ====")
    print(f"签名（base64 编码）: {signature_b64}")

    # 4. 用公钥对签名进行验证
    ok = verify_message(public_key, signature, message)
    print("==== 验证签名 ====")
    print(f"验证结果：{'成功' if ok else '失败'} ")


if __name__ == "__main__":
    run()