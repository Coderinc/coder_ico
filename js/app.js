var $ = jQuery;
var releaseCount;
var reserveBeneficiaries = [];
var reserveLockupTimes = [];
var reservePercents = [];


jQuery(document).ready(function($) {

    let web3 = null;
    let tokenContract = null;
    let crowdsaleContract = null;

    let ethereumPrice = null;


    setTimeout(init, 1000);
    //$(window).on("load", init);
    $('#loadContractsBtn').click(init);

    function init(){
        web3 = loadWeb3();
        if(web3 == null) return;
        //console.log("web3: ",web3);
        loadContract('./eth/build/contracts/CoderCoin.json', function(data){
            tokenContract = data;
            $('#tokenABI').text(JSON.stringify(data.abi));
        });
        loadContract('./eth/build/contracts/CoderCrowdsale.json', function(data){
            crowdsaleContract = data;
            $('#crowdsaleABI').text(JSON.stringify(data.abi));
        });
        initCrowdsaleForm();
        initManageForm();
    }
    function initCrowdsaleForm(){
        let form = $('#publishContractsForm');
        let d = new Date();
        let nowTimestamp = d.setMinutes(0, 0, 0);

        d = new Date(nowTimestamp+1*60*60*1000);
        $('input[name="preSale_baseRate"]', form).val(2000);
        $('input[name="preSale_hardCap"]', form).val(10000);
        $('input[name="ICO_baseRate"]', form).val(1000);
        $('input[name="ICO_hardCap"]', form).val(20000);
        $('input[name="ICO_bonusStartPercent"]', form).val(25);
        $('input[name="ICO_bonusDecreaseInterval"]', form).val(60*60*24);
        $('input[name="ICO_bonusDecreasePercent"]', form).val(1);
        $('input[name="foundersPercent"]', form).val(100);

        setInterval(function(){$('#clock').val( (new Date()).toISOString() )}, 1000);

        web3.eth.getBlock('latest', function(error, result){
            console.log('Current latest block: #'+result.number+' '+timestampToString(result.timestamp), result);
        });
        $.ajax('https://api.coinmarketcap.com/v1/ticker/ethereum/', {'dataType':'json', 'cache':'false', 'data':{'t':Date.now()}})
        .done(function(result){
            console.log('Ethereum ticker from CoinMarketCap:', result);
            ethereumPrice = Number(result[0].price_usd);
            $('#ethereumPrice').html(ethereumPrice);
        });
    };
    function initManageForm(){
        let crowdsale = getUrlParam('crowdsale');
        if(crowdsale){
            $('input[name=crowdsaleAddress]', '#manageCrowdsale').val(crowdsale);
            $('input[name=crowdsaleAddress]', '#lockup_form').val(crowdsale);
            setTimeout(function(){$('#loadCrowdsaleInfo').click();}, 100);
        }
    }

    $('#publishContracts').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#publishContractsForm');

        let tokenAddress = $('input[name="tokenAddress"]', form).val();

        let preSale_baseRate = $('input[name="preSale_baseRate"]', form).val();
        let preSale_hardCap = web3.toWei($('input[name="preSale_hardCap"]', form).val(), 'ether');
        let ICO_baseRate = $('input[name="ICO_baseRate"]', form).val();
        let ICO_hardCap = web3.toWei($('input[name="ICO_hardCap"]', form).val(), 'ether');
        
        let ICO_bonusStartPercent = $('input[name="ICO_bonusStartPercent"]', form).val();
        let ICO_bonusDecreaseInterval = $('input[name="ICO_bonusDecreaseInterval"]', form).val();
        let ICO_bonusDecreasePercent = $('input[name="ICO_bonusDecreasePercent"]', form).val();

        let foundersPercent  = $('input[name="foundersPercent"]', form).val();

        publishContract(crowdsaleContract, 
            [
                preSale_baseRate, preSale_hardCap, ICO_baseRate, ICO_hardCap, 
                ICO_bonusStartPercent, ICO_bonusDecreaseInterval, ICO_bonusDecreasePercent,
                foundersPercent
            ],
            function(tx){
                $('input[name="publishedTx"]',form).val(tx);
            }, 
            function(contract){
                $('input[name="publishedAddress"]',form).val(contract.address);
                $('input[name="crowdsaleAddress"]', '#manageCrowdsale').val(contract.address);
                contract.token(function(error, result){
                    if(!!error) console.log('Can\'t get token address.\n', error);
                    $('input[name="tokenAddress"]',form).val(result);
                });
                $('#loadCrowdsaleInfo').click();
            }
        );
    });
    function setCDRPriceSpanText($span, rate){
        let price = tokenRateToUSDPrice(rate, ethereumPrice);
        $span.html('(1 CDR = '+price+' USD)')
    }
    $('input[name=preSale_baseRate]', '#publishContractsForm').change(function(){
        if(ethereumPrice == null) return;
        setCDRPriceSpanText($('#publish_preSale_basePrice'), $(this).val());
    });
    $('input[name=ICO_baseRate]', '#publishContractsForm').change(function(){
        if(ethereumPrice == null) return;
        setCDRPriceSpanText($('#publish_ICO_basePrice'), $(this).val());
    });


    $('#loadCrowdsaleInfo').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name="crowdsaleAddress"]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        crowdsaleInstance.preSale_startTimestamp(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            if(result > 0){
                $('input[name="preSale_startTimestamp"]', form).val(timestampToString(result));    
            }else{
                $('input[name="preSale_startTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.preSale_baseRate(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="preSale_baseRate"]', form).val(result);
        });
        crowdsaleInstance.preSale_hardCap(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="preSale_hardCap"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.preSale_collected(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="preSale_collected"]', form).val(web3.fromWei(result, 'ether'));
        });

        crowdsaleInstance.ICO_startTimestamp(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            if(result > 0){
                $('input[name="ICO_startTimestamp"]', form).val(timestampToString(result));
            }else{
                $('input[name="ICO_startTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.ICO_baseRate(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_baseRate"]', form).val(result);
        });
        crowdsaleInstance.ICO_hardCap(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_hardCap"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.ICO_collected(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_collected"]', form).val(web3.fromWei(result, 'ether'));
        });

        crowdsaleInstance.ICO_bonusStartPercent(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_bonusStartPercent"]', form).val(result);
        });
        crowdsaleInstance.ICO_bonusDecreaseInterval(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_bonusDecreaseInterval"]', form).val(result);
        });
        crowdsaleInstance.ICO_bonusDecreasePercent(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_bonusDecreasePercent"]', form).val(result);
        });

        crowdsaleInstance.foundersPercent(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="foundersPercent"]', form).val(result);
        });

        crowdsaleInstance.currentRate(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="currentRate"]', form).val(result);
            setCDRPriceSpanText($('#manage_currentRate_price'), result);
        });
        crowdsaleInstance.totalCollected(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="totalCollected"]', form).val(web3.fromWei(result), 'ether');
        });

        web3.eth.getBalance(crowdsaleAddress, function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name=balance]', form).val(web3.fromWei(result, 'ether'));
        });


        crowdsaleInstance.state(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            let state = Number(result);
            $('input[name="contractState"]', form).val(stateNumToName(state));
            if(state < 2){
                $('select[name="newState"]', form).val(state+1);
            }
            
            function stateNumToName(s){
                switch(s){
                    case 0: return 'Paused';
                    case 1: return 'PreSale';
                    case 2: return 'ICO';
                    case 3: return 'Finished';
                    default: return 'Unknown ('+state+')';
                }
            }
        });        


    });
    $('#setState').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name="crowdsaleAddress"]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let newState = $('select[name="newState"]', form).val();
        crowdsaleInstance.setState(newState, function(error, tx){
            if(!!error) {console.log('Contract info loading error:\n', error); return;}
            console.log('State change transaction published. Tx: '+tx);
            waitTxReceipt(tx, function(receipt){
                console.log('State change tx mined', receipt);
                $('#loadCrowdsaleInfo').click();
            });
        });
    });
    
    $('#crowdsaleClaim').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        crowdsaleInstance.claimCollectedEther(function(error, tx){
            if(!!error) {console.log('Can\'t execute claim:\n', error); return;}
            console.log('Claim tx:', tx);
            waitTxReceipt(tx, function(receipt){
                console.log('Claim tx mined', receipt);
                $('#loadCrowdsaleInfo').click();
            });
        });

    });

    $('#add-row').click(() => {
        let releaseCount = $('#lockup_table tbody tr').length + 1;
        var markup = 
        `<tr>
            <td>${releaseCount}</td>
            <td><input type='text' name='address[${releaseCount}]' class="ethAddress"/></td>
            <td><input type='number' name='lockupTime[${releaseCount}]' /></td>
            <td><input type='number' name='percent[${releaseCount}] ' /></td>
        </tr>`;
        $('#lockup_table tbody').append(markup);
    });

    $('#finishCrowdsale').click(function(){
        if(crowdsaleContract == null) return;

        let form = $('#lockup_form');
        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        var everything = $('#lockup_form').serializeArray();

        var benef = [];
        var lockupTimes = [];
        var percents = [];

        let now = Date.now();

        everything.forEach(o => {
            if (/address/.test(o.name)) benef.push(o.value);
            if (/lockupTime/.test(o.name)) lockupTimes.push(now+Number(o.value)*1000);
            if (/percent/.test(o.name)) percents.push(o.value);

        });

        reserveBeneficiaries = benef;
        reserveLockupTimes = lockupTimes;
        reservePercents = percents

        console.log('Lockup arguments',reserveBeneficiaries, reserveLockupTimes, reservePercents);

        crowdsaleInstance.finishCrowdsale(reserveBeneficiaries, reserveLockupTimes, reservePercents, function(error, result){
            if(!!error){
                console.log('Can\'t execute finishCrowdsale:\n', error);
                printError(error.message.substr(0,error.message.indexOf("\n")));
                return;
            }
            console.log('FinishCrowdsale tx:', tx);
            waitTxReceipt(tx, function(receipt){
                console.log('FinishCrowdsale tx mined', receipt);
                $('#loadCrowdsaleInfo').click();
            });
        });

    });

    //====================================================

    function loadWeb3(){
        if(typeof window.web3 == "undefined"){
            printError('No MetaMask found');
            return null;
        }
        let Web3 = require('web3');
        let web3 = new Web3();
        web3.setProvider(window.web3.currentProvider);

        if(typeof web3.eth.accounts[0] == 'undefined'){
            printError('Please, unlock MetaMask');
            return null;
        
        }
        web3.eth.defaultAccount =  web3.eth.accounts[0];
        return web3;
    }
    function loadContract(url, callback){
        $.ajax(url,{'dataType':'json', 
                    'cache':'false', 
                    'data':{'t':Date.now()}
                   }).done(callback);
    }
    function publishContract(contractDef, arguments, txCallback, publishedCallback){
        let contractObj = web3.eth.contract(contractDef.abi);

        let logArgs = arguments.slice(0);
        logArgs.unshift('Creating contract '+contractDef.contract_name+' with arguments:\n');
        logArgs.push('\nABI:\n'+JSON.stringify(contractDef.abi));
        console.log.apply(console, logArgs);

        let publishArgs = arguments.slice(0);
        publishArgs.push({
                from: web3.eth.accounts[0], 
                data: contractDef.bytecode?contractDef.bytecode:contractDef.unlinked_binary, //https://github.com/trufflesuite/truffle-contract-schema
        });
        publishArgs.push(function(error, result){
            waitForContractCreation(contractObj, error, result, txCallback, publishedCallback);
        });
        contractObj.new.apply(contractObj, publishArgs);
    }
    function waitForContractCreation(contractObj, error, result, txCallback, publishedCallback){
        if(!!error) {
            console.error('Publishing failed: ', error);
            printError(error.message.substr(0,error.message.indexOf("\n")));
            return;
        }
        if (typeof result.transactionHash !== 'undefined') {
            if(typeof txCallback == 'function'){
                txCallback(result.transactionHash);
            }
            waitTxReceipt(result.transactionHash, function(receipt){
                let contract = contractObj.at(receipt.contractAddress);
                console.log('Contract mined at: ' + receipt.contractAddress + ', tx: ' + result.transactionHash+'\n', 'Receipt:\n', receipt,  'Contract:\n',contract);
                if(typeof publishedCallback === 'function') publishedCallback(contract);
            });
        }else{
            console.error('Unknown error. Result: ', result);
        }
    }
    function waitTxReceipt(tx, callback){
        let receipt; 
        let timer = setInterval(function(){
            web3.eth.getTransactionReceipt(tx, function(error, result){
                if(!!error) {
                    console.error('Can\'t get receipt for tx '+tx+'.\n', error, result);
                    return;
                }
                if(result != null){
                    clearInterval(timer);
                    if(typeof receipt !== 'undefined') return; //already executed;
                    receipt = result;
                    callback(receipt);
                }
            });
        }, 1000);
    }

    function timeStringToTimestamp(str){
        return Math.round(Date.parse(str)/1000);
    }
    function timestampToString(timestamp){
        return (new Date(timestamp*1000)).toISOString();
    }

    function printError(msg){
        if(msg == null || msg == ''){
            $('#errormsg').html('');    
        }else{
            console.error(msg);
            $('#errormsg').html(msg);
        }
    }
    function getUrlParam(name){
        if(window.location.search == '') return null;
        let params = window.location.search.substr(1).split('&').map(function(item){return item.split("=").map(decodeURIComponent);});
        let found = params.find(function(item){return item[0] == name});
        return (typeof found == "undefined")?null:found[1];
    }
    function tokenRateToUSDPrice(rate, ethPrice){
        return Math.round(10000 * ethPrice / rate)/10000;
    }
});