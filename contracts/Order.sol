// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// RoleContract interface
interface IRoleContract {
    function getManufacturerAddress(address _manufacturer) external view returns (string memory);
    function getDistributorAddress(address _distributor) external view returns (string memory);
    function getRetailerAddress() external view returns (string memory);
    function getDistributorName(address _distributor) external view returns (string memory);

}
contract OrderContract {
    struct Order {
        uint orderId;
        address retailer;
        address manufacturer;
        uint productId;
        uint quantity;
        uint price; 
        DeliveryInfo deliveryInfo; 
        string status;
        address distributor;
        uint temperature;
        string orderHistory;
        string rejectionReason;
    }

    struct DeliveryInfo {
        string deliveryDate;
        string deliveryTime;
        string shippingAddress;
    }

    Order[] public orders;
    uint public orderCounter = 0;
    IRoleContract public roleContract; // Instance of the role contract

    event OrderStatusUpdated(uint orderId, string newStatus);
    event DistributorAssigned(uint orderId, address distributor);


    constructor(address _roleContractAddress) {
        roleContract = IRoleContract(_roleContractAddress);
    }
    // Function to create a new order
    function createOrder(
    uint _productId,
    uint _quantity,
    address _manufacturer,
    string memory _deliveryDate,
    string memory _deliveryTime,
    string memory _shippingAddress,
    uint _productPrice, 
    uint _temperature // Accepting real-time temperature reading from the sensors
) public {
    orderCounter++;
    uint totalPrice = _productPrice * _quantity;

    DeliveryInfo memory delivery = DeliveryInfo({
        deliveryDate: _deliveryDate,
        deliveryTime: _deliveryTime,
        shippingAddress: _shippingAddress
    });
    
 string memory orderHistoryEntry = string(
    abi.encodePacked(
        uintToString(block.timestamp),
        ",Order Created"
     )
 );

    orders.push(Order({
        orderId: orderCounter,
        retailer: msg.sender,
        manufacturer: _manufacturer,
        productId: _productId,
        quantity: _quantity,
        price: totalPrice,
        deliveryInfo: delivery,
        status: "Waiting for manufacturer acceptance",  // Set initial status
        distributor: address(0), // Default value for distributor
        temperature: _temperature, // Storing real-time temperature
        orderHistory: orderHistoryEntry,
        rejectionReason: ""
    }));

    emit OrderStatusUpdated(orderCounter, "Waiting for manufacturer acceptance");
}



    // Function to update the order status with timestamp and history tracking
    function updateOrderStatus(uint _orderId, string memory _newStatus) public {
    require(_orderId > 0 && _orderId <= orderCounter, "Order does not exist.");
    Order storage order = orders[_orderId - 1];

    //  Check if status is already the same
    if (keccak256(bytes(order.status)) == keccak256(bytes(_newStatus))) {
        return; 
    }

    uint currentTime = block.timestamp;

    string memory separator = bytes(order.orderHistory).length == 0 ? "" : ",";
    string memory newHistoryEntry = string(
        abi.encodePacked(
            order.orderHistory,
            separator,
            uintToString(currentTime),
            ",",
            _newStatus
        )
    );

    order.status = _newStatus;
    order.orderHistory = newHistoryEntry;

    emit OrderStatusUpdated(_orderId, _newStatus);
}

function rejectOrderWithReason(uint _orderId, string memory _reason) public {
    require(_orderId > 0 && _orderId <= orderCounter, "Order does not exist.");

    Order storage order = orders[_orderId - 1];

    address manufacturer = order.manufacturer;
    address retailer = order.retailer;
    address distributor = order.distributor;

    string memory rejectionStatus;

    if (msg.sender == manufacturer) {
        rejectionStatus = "Rejected by Manufacturer";
    } else if (msg.sender == retailer) {
        rejectionStatus = "Rejected by Retailer";
    } else if (msg.sender == distributor) {
        rejectionStatus = "Rejected by Distributor";
    } else {
        revert("Unauthorized rejection.");
    }

    order.status = rejectionStatus;
    order.rejectionReason = _reason;

    uint currentTime = block.timestamp;

    string memory separator = bytes(order.orderHistory).length == 0 ? "" : ",";
    string memory newHistoryEntry = string(
        abi.encodePacked(
            order.orderHistory,
            separator,
            uintToString(currentTime),
            ",",
            rejectionStatus
        )
    );
    order.orderHistory = newHistoryEntry;

    emit OrderStatusUpdated(_orderId, rejectionStatus);
}

   
function assignDistributor(uint _orderId, address _distributor) public {
    require(_orderId > 0 && _orderId <= orderCounter, "Order does not exist.");
    Order storage order = orders[_orderId - 1]; // Use zero-based index

    // Validate that the order is in a correct state for distributor assignment
    require(
        keccak256(bytes(order.status)) == keccak256(bytes("Preparing for Dispatch")) ||
        keccak256(bytes(order.status)) == keccak256(bytes("Rejected by Distributor")),
        "Order is not in a valid status for distributor assignment."
    );

    // Ensure a valid distributor address is provided
    require(_distributor != address(0), "Invalid distributor address.");

    // Update the order's distributor and status
    order.distributor = _distributor;
    order.status = "Dispatched";

    // Simplify history update by not including distributor name to save on gas and complexity
    // If it's essential to have the distributor's name, consider fetching and displaying it off-chain
    updateOrderHistory(_orderId, "Assigned to distributor");

    // Emitting events for changes
    emit OrderStatusUpdated(_orderId, "Dispatched");
    emit DistributorAssigned(_orderId, _distributor);
}


    // Function to cancel an order
    function cancelOrder(uint _orderId) public {
        require(_orderId > 0 && _orderId <= orderCounter, "Order does not exist.");
        Order storage order = orders[_orderId - 1];
        order.status = "Canceled";

        string memory newHistoryEntry = string(
            abi.encodePacked(order.orderHistory, ",", uintToString(block.timestamp), ",Canceled")
        );

        order.orderHistory = newHistoryEntry;
        emit OrderStatusUpdated(_orderId, "Canceled");
    }

    
// Helper function to update order history with new event
function updateOrderHistory(uint _orderId, string memory action) internal {
    Order storage order = orders[_orderId - 1];
    uint currentTime = block.timestamp;
    order.orderHistory = string(abi.encodePacked(
        order.orderHistory,
        ",",
        uintToString(currentTime),
        ",",
        action
    ));
}

// Helper function to convert uint to string, more concise than the previous version
function uintToString(uint _value) internal pure returns (string memory) {
    if (_value == 0) {
        return "0";
    }
    uint temp = _value;
    uint digits;
    while (temp != 0) {
        digits++;
        temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (_value != 0) {
        digits -= 1;
        buffer[digits] = bytes1(uint8(48 + _value % 10));
        _value /= 10;
    }
    return string(buffer);
}

   
    // Function to get the address based on order status
    function getAddressForStatus(
        string memory _status,
        address _manufacturer,
        address _distributor
    ) internal view returns (string memory) {
        if (
            keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("Waiting for manufacturer acceptance")) ||
            keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("Paid")) ||
            keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("Waiting for payment"))
        ) {
            return roleContract.getManufacturerAddress(_manufacturer);
        } else if (
            keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("Delivered to retailer")) ||
            keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("Completed"))
        ) {
            return roleContract.getRetailerAddress();
        } else {
            return roleContract.getDistributorAddress(_distributor);
        }
    }


    // Helper function to convert address to string
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
  // Function to get all orders
    function getAllOrders() public view returns (Order[] memory) {
        return orders;
    }
    // Get orders by manufacturer
    function getOrdersByManufacturer(address _manufacturer) public view returns (Order[] memory) {
        uint orderCount = 0;
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].manufacturer == _manufacturer) {
                orderCount++;
            }
        }
        Order[] memory manufacturerOrders = new Order[](orderCount);
        uint index = 0;
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].manufacturer == _manufacturer) {
                manufacturerOrders[index] = orders[i];
                index++;
            }
        }
        return manufacturerOrders;
    }

   

    // Get orders by distributor
    function getOrdersByDistributor(address _distributor) public view returns (Order[] memory) {
        uint orderCount = 0;

        // Count orders assigned to the given distributor
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].distributor == _distributor) {
                orderCount++;
            }
        }

        // Create an array to store distributor orders
        Order[] memory distributorOrders = new Order[](orderCount);
        uint index = 0;

        // Populate the array with matching orders
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].distributor == _distributor) {
                distributorOrders[index] = orders[i];
                index++;
            }
        }

        return distributorOrders;
    }
    
    // Get a single order by ID
function getOrderById(uint _orderId) public view returns (
    uint orderId,
    address retailer,
    address manufacturer,
    uint productId,
    uint quantity,
    uint price,
    DeliveryInfo memory deliveryInfo,
    string memory status,
    address distributor,
    uint temperature,
    string memory orderHistory,
    string memory rejectionReason
) {
    require(_orderId > 0 && _orderId <= orderCounter, "Order does not exist.");
    Order storage order = orders[_orderId - 1];
    return (
        order.orderId,
        order.retailer,
        order.manufacturer,
        order.productId,
        order.quantity,
        order.price,
        order.deliveryInfo,
        order.status,
        order.distributor,
        order.temperature,
        order.orderHistory,
        order.rejectionReason
    );
}

    // Function to update the temperature of an order
function updateOrderTemperature(uint _orderId, uint _temperature) public {
    require(_orderId > 0 && _orderId <= orderCounter, "Order does not exist.");
    
    Order storage order = orders[_orderId - 1];
    order.temperature = _temperature; // Update the temperature
    
}


}

