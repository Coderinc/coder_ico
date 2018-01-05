pragma solidity ^0.4.0;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract KrakenPriceTicker is usingOraclize {

uint public ETHUSD;

event newOraclizeQuery(string description);
event newKrakenPriceTicker(string price);

function KrakenPriceTicker() {
// FIXME: enable oraclize_setProof is production
oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
update(0); //first check at contract creation
}

function __callback(bytes32 myid, string result, bytes proof) {
if (msg.sender != oraclize_cbAddress()) throw;
newKrakenPriceTicker(result);
ETHUSD = parseInt(result, 2); // save it in storage as $ cents
// do something with ETHUSD
// update(60); // FIXME: comment this out to enable recursive price updates
}

function update(uint delay) payable {
if (oraclize_getPrice("URL") > this.balance) {
newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
} else {
newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
oraclize_query(delay, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
}
}

} 
