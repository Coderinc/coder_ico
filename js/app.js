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
        if(web3 == null) {
            setTimeout(init, 5000);
            return;
        }
        //console.log("web3: ",web3);
        loadContract('./eth/build/contracts/CoderCoin.json', function(data){
            tokenContract = data;
            $('#tokenABI').text(JSON.stringify(data.abi));
        });
        loadContract('./eth/build/contracts/CoderCrowdsale.json', function(data){
            crowdsaleContract = data;
            $('#crowdsaleABI').text(JSON.stringify(data.abi));
            initManageForm();
        });
        initCrowdsaleForm();
    }
    function initCrowdsaleForm(){
        let form = $('#publishContractsForm');
        let d = new Date();
        let nowTimestamp = d.setMinutes(0, 0, 0);

        d = new Date(nowTimestamp+1*60*60*1000);
        //$('input[name="preSale_baseRate"]', form).val(1000);
        // $('input[name="preSale_hardCap"]', form).val(20000);       
        //$('input[name="ICO_baseRate"]', form).val(1000);
        // $('input[name="ICO_hardCap"]', form).val(20000);
        // $('input[name="ICO_bonusStartPercent"]', form).val(25);
        // $('input[name="foundersPercent"]', form).val(100);
        $('input[name="minContribution"]', form).val(0.01);
        //$('input[name="goal"]', form).val(1000);

        function addBonus(prefix, threshold, percent){
            let tbody = $('#'+prefix+'BonusTable tbody');
            let num = $('tr', tbody).length;
            $('<tr></tr>').appendTo(tbody)
                .append('<td><input type="number" name="'+prefix+'Bonus_threshold['+num+']" value="'+threshold+'" class="number" min="0"></td>')
                .append('</td><td><input type="number" name="'+prefix+'Bonus_precent['+num+']" value="'+percent+'" class="number" min="0"></td>');
        }
        addBonus('preSale', 500, 50);
        addBonus('preSale', 1500, 45);
        addBonus('preSale', 2500, 40);
        addBonus('preSale', 5000, 35);
        addBonus('preSale', 10000, 30);
        addBonus('preSale', 20000, 25);    //this needs to match exactly presale hard cap in smart contract
        // addBonus($('input[name="preSale_hardCap"]', form).val(), 25);
        //$('input[name="preSaleBonus_threshold\\['+($('#preSaleBonusTable tbody tr').length-1)+'\\]"]', form).prop('readonly', true);
        $('input[name="preSale_hardCap"]', form).change(function(){
            let tbody = $('#preSaleBonusTable tbody');
            let hardCap = $(this).val();
            let last = $('tr', tbody).length - 1;
            $('input[name="preSaleBonus_threshold\\['+last+'\\]"]', form).val(hardCap);
        });
        addBonus('ICO', 25000, 20);
        addBonus('ICO', 30000, 15);
        addBonus('ICO', 40000, 10);
        addBonus('ICO', 50000, 5);
        $('#ICOBonusAddRow').click(function(){
            addBonus('ICO', '', '');
        })


        //additional info
        setInterval(function(){let d = new Date(); $('#clock').val( d.toLocaleString('en-US')+' ==== '+d.toISOString() )}, 1000);
        web3.eth.getBlock('latest', function(error, result){
            console.log('Current latest block: #'+result.number+' '+timestampToString(result.timestamp), result);
        });
        $.ajax('https://api.coinmarketcap.com/v1/ticker/ethereum/', {'dataType':'json', 'cache':'false', 'data':{'t':Date.now()}})
        .done(function(result){
            console.log('Ethereum ticker from CoinMarketCap:', result);
            ethereumPrice = Number(result[0].price_usd);
            $('#ethereumPrice').html(ethereumPrice);
        });
        $('.myLocalTimezone').html(new Date().toString().match(/\(([A-Za-z\s].*)\)/)[1])
    };
    function initManageForm(){
        let crowdsale = getUrlParam('crowdsale');
        if(crowdsale){
            $('input[name=crowdsaleAddress]', '#manageCrowdsale').val(crowdsale);
            $('input[name=crowdsaleAddress]', '#finishCrowdsale').val(crowdsale);
            setTimeout(function(){$('#loadCrowdsaleInfo').click();}, 100);
        }
        
        initDateTimeField($('input[name="preSale_startTimestamp"]', '#manageCrowdsale'));
        initDateTimeField($('input[name="ICO_startTimestamp"]', '#manageCrowdsale'));

        $('input[name=claimRefundAddress]', '#manageCrowdsale').val(web3.eth.accounts[0]);
    }

    $('#publishContracts').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#publishContractsForm');

        let tokenAddress = $('input[name="tokenAddress"]', form).val();

        //let preSale_hardCap = web3.toWei($('input[name="preSale_hardCap"]', form).val(), 'ether');
        //let ICO_hardCap = web3.toWei($('input[name="ICO_hardCap"]', form).val(), 'ether');

        //let foundersPercent  = $('input[name="foundersPercent"]', form).val();
        let minContribution  = web3.toWei($('input[name="minContribution"]', form).val(), 'ether');

        function parseBonusTable(prefix){
            let table = $('#'+prefix+'BonusTable');
            let count = $('tbody tr', table).length;
            let thresholds = new Array();
            let percents = new Array();
            let prev = 0;
            for(let i = 0; i < count; i++){
                let ts = $('input[name='+prefix+'Bonus_threshold\\['+i+'\\]]', table).val().trim();
                let ps = $('input[name='+prefix+'Bonus_precent\\['+i+'\\]]', table).val().trim();
                if(ts == '' && ps == '') continue;
                let t = web3.toWei(ts, 'ether'); let p = Number(ps);
                thresholds.push(t); percents.push(p);
                if(prev >= Number(t)){
                    printError('Wrong '+prefix+' bonus sequence');
                    return;
                }
                prev = Number(t);
            }
            return {
                'thresholds': thresholds,
                'percents': percents
            }
        }

        let preSaleBonuses = parseBonusTable('preSale');
        let icoBonuses = parseBonusTable('ICO');

        let lastPreSaleBonusThreshold = preSaleBonuses.thresholds[preSaleBonuses.thresholds.length-1];
        let lastIcoBonusThreshold = icoBonuses.thresholds[icoBonuses.thresholds.length-1];
        let ICO_hardCap = web3.toBigNumber(lastIcoBonusThreshold).minus(web3.toBigNumber(lastPreSaleBonusThreshold)).toString(10);


        publishContract(crowdsaleContract, 
            [
                preSaleBonuses.thresholds, preSaleBonuses.percents,
                icoBonuses.thresholds, icoBonuses.percents,
                ICO_hardCap, 
                minContribution
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
    });
    $('input[name=ICO_baseRate]', '#publishContractsForm').change(function(){
        if(ethereumPrice == null) return;
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
                setDateTimeFieldValue($('input[name="preSale_startTimestamp"]', form), result);    
            }else{
                $('input[name="preSale_startTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.baseRate(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="baseRate"]', form).val(result);
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
                setDateTimeFieldValue($('input[name="ICO_startTimestamp"]', form), result);    
            }else{
                $('input[name="ICO_startTimestamp"]', form).val('not defined');
            }
        });
        crowdsaleInstance.ICO_hardCap(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_hardCap"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.ICO_collected(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="ICO_collected"]', form).val(web3.fromWei(result, 'ether'));
        });

        crowdsaleInstance.foundersPercent(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="foundersPercent"]', form).val(result);
        });
        crowdsaleInstance.minContribution(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="minContribution"]', form).val(web3.fromWei(result, 'ether'));
        });
        crowdsaleInstance.goal(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="goal"]', form).val(web3.fromWei(result, 'ether'));
        });

        crowdsaleInstance.crowdsaleOpen(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="crowdsaleOpen"]', form).val(result?'yes':'no');
        });
        crowdsaleInstance.currentRate(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="currentRate"]', form).val(result);
            if(result != 0) {
                setCDRPriceSpanText($('#manage_currentRate_price'), result);
            }
        });
        crowdsaleInstance.totalCollected(function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name="totalCollected"]', form).val(web3.fromWei(result), 'ether');
        });

        web3.eth.getBalance(crowdsaleAddress, function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error);  return;}
            $('input[name=balance]', form).val(web3.fromWei(result, 'ether'));
        });

        function loadBonuses(prefix){
            let tbody = $('#'+prefix+'BonusTableInfo tbody');
            tbody.empty();
            let func = prefix == 'preSale'?'preSaleBonuses':'icoBonuses';
            function loadBonus(num){
                crowdsaleInstance[func](num, function(error, result){
                    if(!!error) {console.log('Contract info loading error:\n', error);  return;}
                    let threshold = web3.fromWei(result[0], 'ether');
                    let percent = web3.toDecimal(result[1]);
                    if(threshold != 0 && num < 300){
                        $('<tr></tr>').appendTo(tbody)
                            .append('<td>'+threshold+'</td>')
                            .append('<td>'+percent+'</td>');
                        loadBonus(num+1);
                    }
                });
            }
            loadBonus(0);
        }
        loadBonuses('preSale');
        loadBonuses('ICO');

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
    $('#whitelistSubmit').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name="crowdsaleAddress"]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let who = $('input[name="whitelistAddress"]', form).val();
        if(!web3.isAddress(who)){printError('Whitelist address is not an Ethereum address'); return;}

        let allow = $('input[name="whitelistAllow"]').prop('checked');

        crowdsaleInstance.whitelistAddress(who, allow, function(error, tx){
            if(!!error) {console.log('Contract info loading error:\n', error); return;}
            console.log('WhitelistAddress transaction published. Tx: '+tx);
            waitTxReceipt(tx, function(receipt){
                console.log('WhitelistAddress tx mined', receipt);
                $('input[name="whitelistAddressCheck"]', form).val(who);
                $('#whitelistCheck').click();
            });
        })
    });

    $('#whitelistCheck').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name="crowdsaleAddress"]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let who = $('input[name="whitelistAddressCheck"]', form).val();
        crowdsaleInstance.whitelist(who, function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error); return;}
            $('#whitelistAddressCheckResult').html(result?'Allowed':'Not allowed');
        })
    });

    $('#whitelistAddressesParse').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');
            
        let parseLog = $('#whitelistAddressesParseLog');
        let parseResult = $('#whitelistAddressesParsed');                    
        let parseResultJSON =  $('textarea[name="whitelistAddressesParsedJSON"]', form);
        let parsed = new Array();


        let addressesText = $('textarea[name="whitelistAddresses"]', form).val().trim();
        let parseErrors = 0;
        addressesText.split('\n').forEach(function(elem, idx){
            let addr = elem.trim();
            if(web3.isAddress(addr)){
                parsed.push(addr);
                parseResult.append('<div>'+addr+'</div>');
            }else{
                parseErrors++;
                if(!addr.startsWith('0x') || addr.length != 42){
                    parseLog.append('<div>Line '+(idx+1)+': <i>"'+elem+'"</i> is not an ethereum address</div>')    
                }else{
                    let addrFix = addr.toLowerCase();
                    if(web3.utils.isAddress(addrFix)){
                        parseLog.append('<div>Line '+(idx+1)+': <i>'+addr+'</i> has wrong checksumm</div>')    
                        //parsed.push(addrFix);
                    }else {
                        parseLog.append('<div>Line '+(idx+1)+': <i>'+addr+'</i> has corect format but can not be parsed</div>')
                    }
                }
            }
        });
        parseLog.append('<div>Parsed '+parsed.length+' addresses. Failed to parse: '+parseErrors+'</div>');
        parseResultJSON.val(JSON.stringify(parsed));
        $('#whitelistAddressesParseResult').show();
    });
    $('#whitelistAddressesSubmit').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name="crowdsaleAddress"]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let parseResultJSON =  $('textarea[name="whitelistAddressesParsedJSON"]', form).val();
        let addresses = JSON.parse(parseResultJSON);
        if(typeof addresses != 'object' || addresses.length == 0){
            console.error('Can not parse addresses');
            return;
        }

        crowdsaleInstance.whitelistAddresses(addresses, function(error, tx){
            if(!!error) {console.log('Contract info loading error:\n', error); return;}
            console.log('WhitelistAddresses transaction published. Tx: '+tx);
            waitTxReceipt(tx, function(receipt){
                console.log('WhitelistAddresses tx mined', receipt);
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

    $('#claimRefundCheck').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let beneficiary = $('input[name="claimRefundAddress"]', form).val();
        crowdsaleInstance.refundAvailable(beneficiary, function(error, result){
            if(!!error) {console.log('Contract info loading error:\n', error); return;}
            $('#claimRefundCheckResult').html((result == 0)?'No refund available':web3.fromWei(result, 'ether')+' ETH available');
        });
    });
    $('#claimRefundTo').click(function(){
        if(crowdsaleContract == null) return;
        printError('');
        let form = $('#manageCrowdsale');

        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let beneficiary = $('input[name="claimRefundAddress"]', form).val();
        crowdsaleInstance.refundTo(beneficiary, function(error, tx){
            if(!!error) {console.log('Can\'t execute refund:\n', error); return;}
            console.log('Refund tx:', tx);
            waitTxReceipt(tx, function(receipt){
                console.log('Refund tx mined', receipt);
                $('input[name="claimRefundAddress"]', form).val(beneficiary);
                $('#claimRefundCheck').click();
            });
        });
    });

    $('#add-row').click(() => {
        let releaseCount = $('#lockup_table tbody tr').length + 1;
        var markup = 
        `<tr>
            <td>${releaseCount}</td>
            <td><input type='text' name='address[${releaseCount}]' class="ethAddress"/></td>
            <td><input type='text' name='lockupTime[${releaseCount}]' id="lockupReleaseTime[${releaseCount}]"/></td>
            <td><input type='text' name='percent[${releaseCount}]' /></td>
        </tr>`;
        $('#lockup_table tbody').append(markup);
        let $dateField = $('#lockupReleaseTime\\['+releaseCount+'\\]')
        initDateTimeField($dateField);
        let d = new Date(Date.now()+365*24*60*60*1000); //add 1 year
        d.setHours(0, 0, 0, 0);                         //set time to midnight
        setDateTimeFieldValue($dateField, d.getTime()/1000);
    });
    $('#finishCrowdsaleBtn').click(function(){
        if(crowdsaleContract == null) return;

        let form = $('#finishCrowdsale');
        let crowdsaleAddress = $('input[name=crowdsaleAddress]', form).val();
        if(!web3.isAddress(crowdsaleAddress)){printError('Crowdsale address is not an Ethereum address'); return;}
        let crowdsaleInstance = web3.eth.contract(crowdsaleContract.abi).at(crowdsaleAddress);

        let rows = $('#lockup_table tbody tr').length;
        let reserveBeneficiaries = [];
        let reserveLockupTimes = [];
        let reservePercents = [];
        for(let i=0; i < rows; i++){
            let address = $('input[name=address\\['+(i+1)+'\\]]', form).val()
            if(!web3.isAddress(address)){
                printError('Bad address on row '+(i+1)+': " '+$('input[name=address\\['+(i+1)+'\\]]', form).val()+'"');
                return;
            }
            let timestamp = getDateTimeFieldValue($('input[name=lockupTime\\['+(i+1)+'\\]]', form));
            if(timestamp < Date.now()/1000){
                printError('Bad release date on row '+(i+1)+': "'+$('input[name=lockupTime\\['+(i+1)+'\\]]', form).val()+'"');
                return;
            }
            let percent = Number($('input[name=percent\\['+(i+1)+'\\]]', form).val());
            if(isNaN(percent) ||  percent <= 0 || percent > 100) {
                printError('Bad percent on row '+(i+1)+': "'+$('input[name=percent\\['+(i+1)+'\\]]', form).val()+'"');
                return;
            }

            reserveBeneficiaries[i] = address;
            reserveLockupTimes[i] = timestamp;
            reservePercents[i] = percent;
        }

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

    function initDateTimeField($field){
        //here we can init date/time plugin
    }
    function getDateTimeFieldValue($field){
        let ts = Date.parse($field.val()); 
        return Math.round(ts/1000);
    }
    function setDateTimeFieldValue($field, timestamp){
        let d = new Date(timestamp * 1000);
        $field.val(d.toLocaleString('en-US'));
    }
});