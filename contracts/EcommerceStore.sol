pragma solidity ^0.4.13;

contract EcommerceStore {

    enum ProductStatus { Open, Sold, Unsold }
    enum ProductCondition { New, Used }

    // number of products in the store
    uint public productIndex;

    // keeps track of which products are in which merchant's store (product id => store address)
    mapping (uint => address) productIdInStore;

    // (merchant account address => (number of products in store => product struct))
    mapping (address => mapping(uint => Product)) stores;

    // Product details stored on the blockchain (links references IPFS data)
    struct Product {
        uint id;
        string name;
        string category;
        string imageLink;
        string descLink;
        uint auctionStartTime;
        uint auctionEndTime;
        uint startPrice;
        address highestBidder;
        uint highestBid;
        uint secondHighestBid;
        uint totalBids;
        ProductStatus status;
        ProductCondition condition;
    }

    function EcommerceStore() public {
        // initialize product count
        productIndex = 0;
    }

    function addProductToStore(string _name, string _category, string _imageLink, 
                                string _descLink, uint _auctionStartTime, uint _auctionEndTime, 
                                uint _startPrice, uint _productCondition) public 
    {
        require(_auctionStartTime < _auctionEndTime);
        productIndex += 1;
        Product memory product = Product(productIndex, _name, _category, _imageLink,
                                 _descLink, _auctionStartTime, _auctionEndTime, _startPrice, 
                                 0, 0, 0, 0, ProductStatus.Open, ProductCondition(_productCondition));
        stores[msg.sender][productIndex] = product;
        productIdInStore[productIndex] = msg.sender;
    }

    function getProduct(uint _id) view public returns (Product) {
        Product memory product = stores[productIdInStore[_id]][_id];
        return product;
    }
}