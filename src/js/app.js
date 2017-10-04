var $ = jQuery;
jQuery(document).ready(function($) {

    let web3 = null;
    let tokenContract = null;
    let crowdsaleContract = null;


    setTimeout(init, 1000);
    //$(window).on("load", init);
    $('#loadContractsBtn').click(init);

    function init(){
        web3 = loadWeb3();
        if(web3 == null) return;
        //console.log("web3: ",web3);
        loadContract('testCrowdSale/build/contracts/NigamCoin', function(data){
            tokenContract = data;
            $('#tokenABI').text(JSON.stringify(data.abi));
        });
        loadContract('testCrowdSale/build/contracts/NigamCrowdsale', function(data){
            crowdsaleContract = data;
            $('#crowdsaleABI').text(JSON.stringify(data.abi));
        });
        initCrowdsaleForm();
    }
    function initCrowdsaleForm(){
        let form = $('#publishContractsForm');
        let d = new Date();
        let nowTimestamp = d.setMinutes(0, 0, 0);
        d = new Date(nowTimestamp+1*60*60*1000);
        $('input[name=startTime]', form).val(d.toISOString());
        d = new Date(nowTimestamp+2*60*60*1000);
        $('input[name=endTime]', form).val(d.toISOString());
        $('input[name=rate]', form).val(300);
        $('input[name=ownersPercent]', form).val(10);
        $('input[name=hardCap]', form).val(50000);
        setInterval(function(){$('#clock').val( (new Date()).toISOString() )}, 1000);

        web3.eth.getBlock('latest', function(error, result){
            console.log('Current latest block: #'+result.number+' '+timestmapToString(result.timestamp), result);
        });

    };

    $('#publishContracts').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#publishContractsForm');

        //let tokenAddress = $('input[name=tokenAddress]', form).val();

        let startTimestamp = timeStringToTimestamp($('input[name=startTime]', form).val());
        let endTimestamp  = timeStringToTimestamp($('input[name=endTime]', form).val());
        let rate = $('input[name=rate]', form).val();
        let ownersPercent  = $('input[name=ownersPercent]', form).val();
        let hardCap  = web3.toWei($('input[name=hardCap]', form).val(), 'ether');


        publishContract(crowdsaleContract, 
            [startTimestamp, endTimestamp, rate, ownersPercent, hardCap],
            function(tx){
                $('input[name=publishedTx]',form).val(tx);
            }, 
            function(contract){
                $('input[name=publishedAddress]',form).val(contract.address);
                $('input[name=crowdsaleAddress]', '#manageCrowdsale').val(contract.address);
                contract.token(function(error, result){
                    if(!!error) console.log('Can\'t get token address.\n', error);
                    $('input[name=tokenAddress]',form).val(result);
                });
            }
        );
    });
    $('#loadCrowdsaleInfo').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        crowdsaleInstance.startTimestamp(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=startTime]', form).val(timestmapToString(result));
        });
        crowdsaleInstance.endTimestamp(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=endTime]', form).val(timestmapToString(result));
        });
        crowdsaleInstance.rate(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=rate]', form).val(result);
        });
        crowdsaleInstance.collectedEther(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=collectedEther]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.hardCap(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=hardCap]', form).val(web3.fromWei(result, 'ether'));
        });
        web3.eth.getBalance(crowdsaleAddress, function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=balance]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.token(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name=tokenAddress]', form).val(result);
        });
    });
    $('#crowdsaleClaim').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        crowdsaleInstance.claimEther(function(error, tx){
            if(!!error){
                console.log('Can\'t execute claim:\n', error);
                printError(error.message.substr(0,error.message.indexOf("\n")));
                return;
            }
            console.log('Claim tx:', tx);
            $('#loadCrowdsaleInfo').click();
        });

    });
    $('#crowdsaleFinalize').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        crowdsaleInstance.finalizeCrowdsale(function(error, tx){
            if(!!error){
                console.log('Can\'t execute finalizeCrowdsale:\n', error);
                printError(error.message.substr(0,error.message.indexOf("\n")));
                return;
            }
            console.log('FinalizeCrowdsale tx:', tx);
            $('#loadCrowdsaleInfo').click();
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
        return web3;
    }
    function loadContract(url, callback){
        debugger;
        $.ajax(url,{'dataType':'json', 'cache':'false', 'data':{'t':Date.now()}}).done(callback);
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
                data: contractDef.unlinked_binary,
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
            let receipt; 
            let timer = setInterval(function(){
                web3.eth.getTransactionReceipt(result.transactionHash, function(error2, result2){
                    if(!!error2) {
                        console.error('Can\'t get receipt for tx '+result.transactionHash+'.\n', error2, result2);
                        return;
                    }
                    if(result2 != null){
                        clearInterval(timer);
                        if(typeof receipt !== 'undefined') return; //already executed;
                        receipt = result2;
                        let contract = contractObj.at(receipt.contractAddress);
                        console.log('Contract mined at: ' + receipt.contractAddress + ', tx: ' + result.transactionHash+'\n', 'Receipt:\n', receipt,  'Contract:\n',contract);
                        if(typeof publishedCallback === 'function') publishedCallback(contract);
                    }
                });
            }, 1000);
        }else{
            console.error('Unknown error. Result: ', result);
        }
    }

    function timeStringToTimestamp(str){
        return Math.round(Date.parse(str)/1000);
    }
    function timestmapToString(timestamp){
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
});