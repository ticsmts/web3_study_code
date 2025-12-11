//SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

contract SolidityStudy1{
    //值的类型：bool, uint, int, address, bytes32..
    bool public _bool = true;
    uint public _uint = 1; // 0 到 2**256-1 , uint8, uint16, uint256
    int public _int = -123; // int256, int 128

    int public _minInt = type(int).min;
    int public _maxInt = type(int).max;

    address public _addr = 0x7C71cd6E4AC41bBD538D8E5b2dA06edA58DE4993;
    bytes32 public _b32;

    //function 方法
    function add(uint x, uint y) external pure returns (uint) {
        return x + y;
    }

    function sub(uint x, uint y) external pure returns (uint){
        return x - y;
    }

    //状态变量，局部变量，全局变量
    uint public _myStateVariables = 666; //状态变量，初始值666，上链保存，一旦部署上链，只能通过交易（调用写入函数）来修改。
    function studyStateVariables() external pure returns (uint){
        uint notStateVariable = 999;  //局部变量，在函数内部，只有在调用这个函数的时候才会在虚拟机的内存中产生。局部变量不能使用可见性修饰符（public, private, external, internal），
        return notStateVariable;
   }


   function studyLocalVariables() external { //部署完后，左侧按钮变成橙色，代表studyLocalVariables为写入方法，会改变链上状态
        uint x = 1;
        bool b = false;
        x += 6;
        b = true;

        _myStateVariables += 2;
   }

    //全局变量
    function studyGlobalVariable() external  view returns (address , uint , uint ){ // pure和view都是只读，view可以读状态变量和全局变量，但不能修改状态（不能写入storage），但是pure不能读取状态变量，pure通常做纯计算
        address sender = msg.sender; // 调用这个函数的地址，可能是一个外部账户，也可能是调用合约的另一个合约
        uint timestamp = block.timestamp; //当前按下按钮的时间戳，如果是写入的方法，就是出块的实践，并不是真实的实践
        uint blockNum =  block.number; //返回区块的区块号
        return (sender, timestamp, blockNum);

    }

    //只要读取链上的数据和全局变量，需要写成view。pure只有局部的变量
    uint public stateVariable0 = 1;
    function viewFunc(uint x) external view returns (uint) {
        return stateVariable0 + x;
    }

    function pureFunc(uint x, uint y) external pure returns (uint){
        return x + y;
    }

    uint public counter = 0;
    function inc() external { //需要改变状态变量，所以不能用pure和view
        counter += 1;
    }
    function dec() external { // external 表示方法只能在合约外部调用，不能在内部调用
        counter -= 1;
    }

    //默认值，状态变量在编译和部署后的默认值
    bool public a_b; //false
    uint public a_ui; // 0
    int public a_i; // 0
    address public a_a; // 0x 40个0
    bytes32 public a_b32; // 0x 64个0

    //常量，上链之后不需要修改的一些固定值，如管理员的地址，一些固定值，可以节约gas费
    address public constant MY_ADDRESS = 0x7C71cd6E4AC41bBD538D8E5b2dA06edA58DE4993; //418gas
    uint public constant MY_UINT = 123; //371gas
    address public my_address2 = 0x7C71cd6E4AC41bBD538D8E5b2dA06edA58DE4993; //2554gas
    uint public my_uint2 = 123; //2494gas

    //if else
    function ifElse(uint x) external pure returns (uint){
        if (x < 10){
            return 10;
        }else if (x < 20){
            return 20;
        }
        return 30;
    }

    function ifElse2(uint x) external pure returns (uint){
        return x < 10 ? 1 : 2;
    }

    //循环控制：for
    function loopFun() external pure{
        for (uint i = 0; i < 10; i++){
            //code
            if (i == 3){
                continue; //继续执行循环
            }
            // more code
            if (i == 5){
                break; //跳出循环
            }

        }

        uint x = 1;
        while(x < 10){
            x++;
        }
    }

    function sumFun(uint _n) external pure returns (uint){
        uint s = 0;
        for(uint i = 0; i <_n; i++){
            s += i;
        }
        return s;
    }
}