pragma solidity ^0.4.17;
// v1.0

import "./../aux/Mortal.sol";
import "./RegistryStorage.sol";

contract Registry is Mortal {  

    event LogNewProvider(
        address indexed provider,
        uint256 indexed publicKey,
        bytes32 indexed title
    );

    event LogNewCurve(
        address indexed provider,
        bytes32 indexed endpoint,
        RegistryStorage.CurveType curveType,
        uint128 curveStart,
        uint128 curveMultiplier
    );

    RegistryStorage stor;

    function Registry(address storageAddress) public {
        stor = RegistryStorage(storageAddress);
    }

    /// @dev Initiates a provider.
    /// If no address->Oracle mapping exists, Oracle object is created
    /// @param publicKey unique id for provider. used for encyrpted key swap for subscription endpoints
    /// @param title name
    /// @param endpoint specifier 
    /// @param endpointParams endpoint specific params
    function initiateProvider(
        uint256 publicKey,
        bytes32 title, 
        bytes32 endpoint,
        bytes32[] endpointParams
    )
        public
        returns (bool)
    {
        if(getProviderPublicKey(msg.sender) == 0) {
            stor.createOracle(msg.sender, publicKey, title);
            if(endpoint != 0)
                setEndpointParams(endpoint, endpointParams);

            stor.addOracle(msg.sender);
            LogNewProvider(msg.sender, publicKey, title);
            return true;
        }
        return false;
    }

    /// @dev Initiates an endpoint specific provider curve
    /// If oracle[specfifier] is uninitialized, Curve is mapped to endpoint
    /// @param endpoint specifier of endpoint. currently "smart_contract" or "socket_subscription"
    /// @param curveType dot-cost vs oracle-specific dot-supply
    /// @param curveStart y-offset of cost( always initial cost )
    /// @param curveMultiplier coefficient to curveType
    function initiateProviderCurve(
        bytes32 endpoint,
        RegistryStorage.CurveType curveType,
        uint128 curveStart,
        uint128 curveMultiplier
    )
        public
        returns (bool)
    {
        RegistryStorage.CurveType cType;
        (cType,) = stor.getCurve(msg.sender, endpoint);

        if (stor.getPublicKey(msg.sender) != 0                   // Provider must be initiated
            && curveType != RegistryStorage.CurveType.None       // Can't use None
            && cType == RegistryStorage.CurveType.None           // Can't reset their curve
        ) {
            stor.setCurve(msg.sender, endpoint, curveType, curveStart, curveMultiplier);
            LogNewCurve(msg.sender, endpoint, curveType, curveStart, curveMultiplier);
            return true;
        }
        return false;
    }

    function setEndpointParams(bytes32 endpoint, bytes32[] endpointParams) public {
        stor.setEndpointParameters(msg.sender, endpoint, endpointParams);
    }

    /// @return public key
    function getProviderPublicKey(address provider) public view returns (uint256) {
        return stor.getPublicKey(provider);
    }

    /// @return oracle name
    function getProviderTitle(address provider) public view returns (string) {
        return bytes32ToStr(stor.getTitle(provider));
    }

    /// @return endpoint-specific parameter
    function getNextEndpointParam(address provider, bytes32 endpoint, uint256 index)
        public
        view
        returns (uint256 nextIndex, bytes32 endpointParam)
    {
        uint256 len = stor.getEndpointIndexSize(provider, endpoint);
        if (index < len) {
            endpointParam = stor.getEndPointParam(provider, endpoint, index);
            if (index + 1 < len) return (index + 1, endpointParam);
            return (0, endpointParam);
        }
        return(0,0);
    }

    /// @dev Get curve paramaters from oracle
    function getProviderCurve(
        address provider,
        bytes32 endpoint
    )        
        public
        view
        returns (
            RegistryStorage.CurveType curveType,
            uint128 curveStart,
            uint128 curveMultiplier
        )
    {
        return stor.getCurve(provider, endpoint);
    }

    function getNextProvider(uint256 index)
        public
        view        
        returns (uint256 nextIndex, address oracleAddress, uint256 publicKey, string title)
    {
        uint256 len = stor.getOracleIndexSize();
        if (index < len) {
            oracleAddress = stor.getOracleAddress(index);
            if (index + 1 < len)
                return (
                    index + 1, 
                    oracleAddress, 
                    getProviderPublicKey(oracleAddress), 
                    getProviderTitle(oracleAddress)
                );            
            return (
                0, 
                oracleAddress, 
                getProviderPublicKey(oracleAddress), 
                getProviderTitle(oracleAddress)
            );                            
        }
        return (0,0x0,0,"");
    }

    function bytes32ToStr(bytes32 _bytes32) private pure returns (string) {
        bytes memory bytesArray = new bytes(32);

        for (uint256 i; i < 32; i++)
            bytesArray[i] = _bytes32[i];
        return string(bytesArray);
    }
}
