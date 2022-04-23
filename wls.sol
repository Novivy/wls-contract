//SPDX-License-Identifier:UNLICENSED
pragma solidity >=0.7.0 <0.9.0;


contract WLS
{
    mapping (address => uint) public balances;
    mapping (uint256 => bool) public usedNonces;

    string public name = "Win Live Stars";
    string public symbol = "WLS";

    //address walletSupply = msg.sender; //commented so we can use an offline wallet
    address walletSupply = 0xb31F29dc87dC77B41495C100A9C760166A2A707E; //cold storage

    address walletCashRegister = 0x36774AaD22190ac0E5048CC5A2C4B8026547D84C; //Used as a layer of security

    address walletTeamMember1 = 0xa5d5FE2f4079178D3296Ded933374f4Cae06D901; //Unlock after 365 days unless we increase it
    address walletTeamMember2 = 0xa5d5FE2f4079178D3296Ded933374f4Cae06D902;
    address walletTeamMember3 = 0xa5d5FE2f4079178D3296Ded933374f4Cae06D903;
    address walletTeamMember4 = 0xa5d5FE2f4079178D3296Ded933374f4Cae06D904;

    address walletBurn = 0x77AC0F1Ab9aBDbf6874a4e759E84447E405f61d6; //Locked forever

    uint public decimals = 18;

    uint private teamWalletsUnlockTime = block.timestamp + (86400 * 365); //Team wallets are locked for the first 365 days

    bool private maintenanceMode = false;

    event Transfer(address indexed from, address indexed to, uint value);

    constructor()  {

        uint supply = 100000000;

        uint teamMemberShare = 100000;

        balances[walletTeamMember1] = teamMemberShare * (10 ** decimals);
        balances[walletTeamMember2] = teamMemberShare * (10 ** decimals);
        balances[walletTeamMember3] = teamMemberShare * (10 ** decimals);
        balances[walletTeamMember4] = teamMemberShare * (10 ** decimals);

        supply = supply - (4 * teamMemberShare);


        uint cashRegisterShare = 50000;
        balances[walletCashRegister] = cashRegisterShare * (10 ** decimals);

        supply = supply - cashRegisterShare;


        balances[walletSupply] = supply * (10 ** decimals);
    }

    function balanceOf(address user) public view returns (uint)
    {
        return balances[user];
    }

    function transfer(address to, uint value) public returns (bool)
    {
        require(!maintenanceMode, "Token maintenance");
        require(balanceOf(msg.sender)>=value, "Insufficient funds");


        if(msg.sender == walletTeamMember1 || msg.sender == walletTeamMember2 || msg.sender == walletTeamMember3 || msg.sender == walletTeamMember4) {

            require(block.timestamp > teamWalletsUnlockTime, "Team wallets are still locked");
        }

        require(msg.sender != walletBurn, "Burn wallet forever locked");



        balances[to]+=value;
        balances[msg.sender]-=value;

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function maintenance(bool value) public returns (bool)
    {

        require(walletSupply == msg.sender, "Contract owner only");

        maintenanceMode = value;

        return true;
    }


    function getTeamUnlockTime() public view returns (uint)
    {
        return teamWalletsUnlockTime;
    }

    function increaseTeamLockTime(uint value) public returns (bool)
    {

        require(walletSupply == msg.sender, "Contract owner only");

        teamWalletsUnlockTime += value;

        return true;
    }

    function claim(uint256 amount, uint256 nonce, bytes memory signature) external returns (bool) {

        require(!maintenanceMode, "Token maintenance");
        require(!usedNonces[nonce], "Duplicate transaction");
        usedNonces[nonce] = true;

        bytes32 message = prefixed(keccak256(abi.encodePacked(msg.sender, amount, nonce, this)));

        require(recoverSigner(message, signature) == walletCashRegister, "Wrong hash");

        require(balances[walletCashRegister] > amount, "Not enough tokens available");

        balances[walletCashRegister]-=amount;
        balances[msg.sender]+=amount;

        emit Transfer(walletCashRegister, msg.sender, amount);

        return true;
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
}
