var $ = jQuery;
var releaseCount;
var reserveBeneficiaries = [];
var reserveLockupTimes = [];
var reservePercents = [];


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
        $('input[name="startTimePresale1"]', form).val(d.toISOString());
        d = new Date(nowTimestamp+2*60*60*1000);
        $('input[name="endTimePresale1"]', form).val(d.toISOString());
        $('input[name="preSaleBasePriceInWei"]', form).val(3333333333333333);
        $('input[name="preSaleEthHardCap"]', form).val(1667);
        $('input[name="ICO_basePriceInWei"]', form).val(3333333333333333);
        $('input[name="ICO_EthHardCap"]', form).val(166667);
        $('input[name="bonusDecreaseInterval"]', form).val(60*60*24);
        $('input[name="ownersPercent"]', form).val(100);

        setInterval(function(){$('#clock').val( (new Date()).toISOString() )}, 1000);

        web3.eth.getBlock('latest', function(error, result){
            console.log('Current latest block: #'+result.number+' '+timestampToString(result.timestamp), result);
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
    // $('#publishToken').click(function(){
    //     if(tokenContract == null) return;
    //     printError('');
    //     let form = $('#publishContractsForm');

    //     publishContract(tokenContract,[],
    //         function(tx){
    //             $('input[name="publishedTx"]',form).val(tx);
    //         }, 
    //         function(contract){
    //                 $('input[name="tokenAddress"]',form).val(contract.address);
    //         }
    //     );
    // });

    $('#publishContracts').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#publishContractsForm');

        let tokenAddress = $('input[name="tokenAddress"]', form).val();

        let preSale_startTimestamp = timeStringToTimestamp($('input[name="startTimePresale"]', form).val());
        let preSale_endTimestamp  = timeStringToTimestamp($('input[name="endTimePresale"]', form).val());
        let ICO_startTimestamp = timeStringToTimestamp($('input[name="startTimeICO"]', form).val());
        let ICO_endTimestamp  = timeStringToTimestamp($('input[name="endTimeICO"]', form).val());
        let preSaleBasePriceInWei = $('input[name="preSaleBasePriceInWei"]', form).val();
        let preSaleEthHardCap = $('input[name="preSaleEthHardCap"]', form).val();
        let ICO_basePriceInWei = $('input[name="ICO_basePriceInWei"]', form).val();
        let ICO_EthHardCap = $('input[name="ICO_EthHardCap"]', form).val();
        let bonusDecreaseInterval = $('input[name="bonusDecreaseInterval"]', form).val();
        let ownersPercent  = $('input[name="ownersPercent"]', form).val();

        publishContract(crowdsaleContract, 
            [preSaleBasePriceInWei, preSaleEthHardCap, ICO_basePriceInWei, ICO_EthHardCap, bonusDecreaseInterval, ownersPercent],
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
                $('input[name="balance"]', '#manageCrowdsale').val(contract.balance);
            }
        );
    });


    $('#loadCrowdsaleInfo').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name="crowdsaleAddress"]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        crowdsaleInstance.preSale_startTimestamp(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            if(result > 0){
                $('input[name="preSale_startTimestamp"]', form).val(timestampToString(result));    
            }else{
                $('input[name="preSale_startTimestamp"]', form).val('not defined');
            }
            
        });
        crowdsaleInstance.preSale_endTimestamp(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            if(result > 0){
                $('input[name="preSale_endTimestamp"]', form).val(timestampToString(result));
            }else{
                $('input[name="preSale_endTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.preSaleEthHardCap(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="preSaleEthHardCap"]', form).val(result);
        });

        crowdsaleInstance.ICO_startTimestamp(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            if(result > 0){
                $('input[name="ICO_startTimestamp"]', form).val(timestampToString(result));
            }else{
                $('input[name="ICO_startTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.ICO_endTimestamp(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            if(result > 0){
                $('input[name="ICO_endTimestamp"]', form).val(timestampToString(result));
            }else{
                $('input[name="ICO_endTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.ICO_EthHardCap(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="ICO_EthHardCap"]', form).val(result);
        });

        crowdsaleInstance.bonusDecreaseInterval(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="bonusDecreaseInterval"]', form).val(result);
        });
        crowdsaleInstance.ownersPercent(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="ownersPercent"]', form).val(result);
        });
/*
        crowdsaleInstance.rate(function(error, result){             //currentRate function from contract
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="rate"]', form).val(result);
        });
        crowdsaleInstance.preSaleEthCollected(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="preSale1EthCollected"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.ICO_EthCollected(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="ICO_EthCollected"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.getBalance(crowdsaleAddress, function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="balance"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.token(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
            $('input[name="tokenAddress"]', form).val(result);
        });
*/        
        crowdsaleInstance.state(function(error, result){
            if(!!error) console.log('Contract info loading error:\n', error);
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
            if(!!error) console.log('Contract info loading error:\n', error);
            console.log('State change transaction published. Tx: '+tx);

            let receipt;
            let timer = setInterval(function(){
                web3.eth.getTransactionReceipt(tx, function(error2, result2){
                    if(!!error2) {
                        console.error('Can\'t get receipt for tx '+result.transactionHash+'.\n', error2, result2);
                        return;
                    }
                    if(result2 != null){
                        clearInterval(timer);
                        if(typeof receipt !== 'undefined') return; //already executed;
                        receipt = result2;
                         $('#loadCrowdsaleInfo').click();
                    }
                });
            }, 1000);

        });
    });
    

    // $('#switchState1').click(function(){
    //     if(crowdsaleContract == null) return;
    //     printError('');
    //     let form = $('#manageCrowdsale');

    //     crowdsaleInstance.setState(1, function (error, result){
    //         if(!!error){
    //             console.log('Can\'t switch state to Presale Round 1:\n', error);
    //             printError(error.message.substr(0,error.message.indexOf("\n")));
    //             return;
    //         }
    //         console.log('State:', result);
    //         $('#loadCrowdsaleInfo').click();
    //     });
    // })
    // $('#switchState2').click(function(){
    //     if(crowdsaleContract == null) return;
    //     printError('');
    //     let form = $('#manageCrowdsale');

    //     crowdsaleInstance.setState(2, function (error, result){
    //         if(!!error){
    //             console.log('Can\'t switch state to Presale Round 2:\n', error);
    //             printError(error.message.substr(0,error.message.indexOf("\n")));
    //             return;
    //         }
    //         console.log('State:', result);
    //         $('#loadCrowdsaleInfo').click();
    //     });
    // })
    // $('#switchState3').click(function(){
    //     if(crowdsaleContract == null) return;
    //     printError('');
    //     let form = $('#manageCrowdsale');

    //     crowdsaleInstance.setState(3, function (error, result){
    //         if(!!error){
    //             console.log('Can\'t switch state to ICO Round:\n', error);
    //             printError(error.message.substr(0,error.message.indexOf("\n")));
    //             return;
    //         }
    //         console.log('State:', result);
    //         $('#loadCrowdsaleInfo').click();
    //     });
    // })
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

    $('#lockup').click(function(){
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
            console.log(error,result);
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
});