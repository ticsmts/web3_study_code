#encoding=utf-8

'''
模拟实现最小的区块链， 包含两个功能：

1. POW 证明出块，难度为 4 个 0 开头
2. 每个区块包含previous_hash 让区块串联起来。

如下是一个参考区块结构：

block = {
'index': 1,
'timestamp': 1506057125,
'transactions': [{
    'sender': "xxx",
    'recipient': "xxx",
    'amount': 5,
    }],
'proof': 324984774000,
'previous_hash': "xxxx"
}

'''


import hashlib
import json
import time

class Blockchain:
    def __init__(self):
        self.chain = []
        self.current_transactions = []

        #创世区块
        self.new_block(previous_hash="1", proof=100)

    def new_block(self, proof, previous_hash=None):
        '''
        创建新区块
        :param proof:
        :param previous_hash:
        :return:
        '''

        block = {
            'index':len(self.chain)+1,
            'timestamp': time.time(),
            'transactions': self.current_transactions,
            'proof': proof,
            'previous_hash': previous_hash or self.hash(self.chain[-1])
        }

        self.current_transactions = []

        self.chain.append(block)
        return block


    def new_transaction(self, sender, recipient, amount):
        '''
        创建新交易
        :param sender: 发送者地址
        :param recipient: 接受者地址
        :param amount: 数量
        :return: 保存该交易的新区块的index
        '''
        self.current_transactions.append({
             'sender': sender,
             'recipient': recipient,
             'amount': amount
             })
        return self.last_block['index'] + 1

    @staticmethod
    def hash(block):
        '''
        静态方法，对区块进行hash
        :param block: 区块
        :return: 该区块的sha256 hash值
        '''
        block_string = json.dumps(block, sort_keys=True).encode()
        return hashlib.sha256(block_string).hexdigest()

    @property
    def last_block(self):
        return self.chain[-1]

    def proof_of_work(self, last_proof):
        '''
        :param last_proof: 上一个区块的工作量证明
        :return: 区块的proof
        '''
        proof = 0
        while self.valid_proof(last_proof, proof) is False:
            proof += 1
        return proof

    @staticmethod
    def valid_proof(last_proof, proof):
        '''
        自定义POW: 寻找一个数 proof，使得它与前一个区块的 proof 拼接成的字符串的 Hash 值以 4 个零开头。
        :param last_proof: 前一个区块的proof值
        :param proof: 当前区块需要计算的工作量证明proof
        :return: 验证失败返回False，验证成功返回True
        '''
        text = f"{last_proof}{proof}"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if (h.startswith("0000")):
            print(f'{last_proof}{proof} 哈希值为: {h}')
            return True
        else:
            return False

def main():
    blockchain = Blockchain()
    print("创世区块: ")
    print(json.dumps(blockchain.chain[0], indent=2, ensure_ascii=False))
    print("-" * 40)

    #模拟挖3个区块
    for i in range(3):
        # 1. 创建交易
        blockchain.new_transaction(f'Alice{i}', f'Bob{i}', 100)
        blockchain.new_transaction('system', 'Satoshi', 100)

        # 2. 挖矿
        last_block = blockchain.last_block
        last_proof = last_block['proof']
        print(f"开始为区块 {last_block['index'] + 1} 挖矿...")
        start = time.time()
        proof = blockchain.proof_of_work(last_proof)
        cost = time.time() - start
        print(f"找到 proof={proof}，耗时 {cost:.4f} 秒")


        # 3. 打包新区块
        block = blockchain.new_block(proof)
        print("新区块：")
        print(json.dumps(block, indent=2, ensure_ascii=False))
        print("-" * 40)

    print("最终整条链：")
    print(json.dumps(blockchain.chain, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()





