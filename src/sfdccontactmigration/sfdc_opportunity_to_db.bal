import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerinax/sfdc;

sfdc:SalesforceConfiguration sfConfig = {
    baseUrl: config:getAsString("SF_EP_URL"),
    clientConfig: {
        accessToken: config:getAsString("SF_ACCESS_TOKEN"),
        refreshConfig: {
            clientId: config:getAsString("SF_CLIENT_ID"),
            clientSecret: config:getAsString("SF_CLIENT_SECRET"),
            refreshToken: config:getAsString("SF_REFRESH_TOKEN"),
            refreshUrl: config:getAsString("SF_REFRESH_URL")
        }
    }
};

sfdc:ListenerConfiguration listenerConfig = {
    username: config:getAsString("SF_USERNAME"),
    password: config:getAsString("SF_PASSWORD")
};

sfdc:BaseClient baseClient = new(sfConfig);

listener sfdc:Listener sfdcEventListener = new (listenerConfig);

@sfdc:ServiceConfig {
    topic:"/topic/OpportunityUpdate"
}
service sfdcOpportunityListener on sfdcEventListener {
    resource function onEvent(json op) {  
        //convert json string to json
        io:StringReader sr = new(op.toJsonString());
        json|error opportunity = sr.readJson();
        if (opportunity is json) {
            log:printInfo("Opportunity Stage : " + opportunity.sobject.StageName.toString());
            //check if opportunity is closed won
            if (opportunity.sobject.StageName == "Closed Won") {
                //get the account id from the opportunity
                string accountId = opportunity.sobject.AccountId.toString();
                log:printInfo("Account ID : " + accountId);
                //create sobject client
                sfdc:SObjectClient sobjectClient = baseClient->getSobjectClient();
                //get account
                json|sfdc:Error account = sobjectClient->getAccountById(accountId);

                // sfdc:QueryClient qClient = baseClient->getQueryClient(); 
                // qClient->getQueryResult()
                
                if (account is json) {
                    //extract required fields from the account record
                    string accountName = account.Name.toString();
                    log:printInfo("Account Name : " + accountName);
                    //Target connector to follow
                    // Database Operations goes here. 
                    
                }
            }
        }
    }
}