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
        // which user bids and what product they bid on
        // (address of bidder => (hashed bid string => bid struct))
        mapping (address => mapping (bytes32 => Bid)) bids;
    }

    struct Bid {
        address bidder;
        uint productId;
        uint value; // amount sent by bidder (not amount being bid, which is encrypted)
        bool revealed;
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

    function getProduct(uint _id) view public returns (uint, string, string, string, string, uint, uint, uint, ProductStatus, ProductCondition) {
        Product memory product = stores[productIdInStore[_id]][_id];
        return (product.id, product.name, product.category, product.imageLink, 
        product.descLink, product.auctionStartTime, product.auctionEndTime, 
        product.startPrice, product.status, product.condition);
    }

    // user can bid an amount on any given record
    // in order to generate a sealed bid (can't see bid amount), user must call the sha3 function
    // *pass amount user is bidding and the secret string into the sha3 hashing function*
    // sha3("10.5" + "secretstring").toString('hex') => c2f8990ee5acd17d421d22647f20834cc37e20d0ef11087e85774bccaf782737
    // @param productId: product ID, bid: encrypted bid string
    function bid(uint _productId, bytes32 _bid) payable public returns (bool) {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        require (now >= product.auctionStartTime);
        require (now <= product.auctionEndTime);
        require (msg.value > product.startPrice);
        require (product.bids[msg.sender][_bid].bidder == 0);
        // msg.value is the amt sent (not amt bidded, which is encrypted)
        product.bids[msg.sender][_bid] = Bid(msg.sender, _productId, msg.value, false);
        product.totalBids += 1;
        return true;
    }

    // revealing tells the contract how much the user bid (actual amount is initially encrypted)
    // uses sha3 algorithm to ccheck that bid amt + secret generates same hash as in bids mapping
    function revealBid(uint _productId, string _amount, string _secret) public {
        Product storage product = stores[productIdInStore[_productId]][_productId];
        require (now > product.auctionEndTime);
        bytes32 sealedBid = sha3(_amount, _secret);

        Bid memory bidInfo = product.bids[msg.sender][sealedBid];
        require (bidInfo.bidder > 0);
        require (bidInfo.revealed == false);

        uint refund;
        uint amount = stringToUint(_amount);

        if (bidInfo.value < amount) {
            // they didn't send enough money (sent less than their bid amount)
            refund = bidInfo.value;
        } else {
            // if it's the first bid to reveal for product, set as highest bidder
            if (address(product.highestBidder) == 0) {
                product.highestBidder = msg.sender;
                product.highestBid = amount;
                product.secondHighestBid = product.startPrice;
                refund = bidInfo.value - amount;
            } else {
                // bid is higher than current highest revealed bid
                // record bidder and bid as highest, set second highest value to old bid amt
                if (amount > product.highestBid) {
                    product.secondHighestBid = product.highestBid;
                    product.highestBidder.transfer(product.highestBid);
                    product.highestBidder = msg.sender;
                    product.highestBid = amount;
                    refund = bidInfo.value - amount;
                } else if (amount > product.secondHighestBid) {
                    // reset second highest bid but refund item because they lost
                    product.secondHighestBid = amount;
                    refund = amount;
                } else { // refund the item because they lost (bid is lower than highest bid)
                    refund = amount;
                }
            }
            if (refund > 0) {
                msg.sender.transfer(refund);
                product.bids[msg.sender][sealedBid].revealed = true;
            }
        }
    }

    // Helper Methods

    // returns the highest bidder info for a product
    function highestBidderInfo(uint _productId) view public returns (address, uint, uint) {
        Product memory product = stores[productIdInStore[_productId]][_productId];
        // return highest bid address, highest bid value, and second highest bid value
        return (product.highestBidder, product.highestBid, product.secondHighestBid);
    }

    // returns total number of bids for a product
    function totalBids(uint _productId) view public returns (uint) {
        Product memory product = stores[productIdInStore[_productId]][_productId];
        return product.totalBids;
    }

    function stringToUint(string str) pure private returns(uint) {
        bytes memory b = bytes(str);
        uint result = 0;
        for (uint x = 0; x < b.length; x++) {
            if (b[x] >= 48 && b[x] <= 57) {
                result = result * 10 + (uint(b[x]) - 48);
            }
        }
        return result;
    }
    
}