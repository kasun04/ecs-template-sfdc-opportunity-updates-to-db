import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerinax/sfdc;
import ballerina/mysql;
import ballerina/sql;

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
mysql:Client mysqlClient =  check new (user = config:getAsString("DB_USER"),
                                        password = config:getAsString("DB_PWD"));



@sfdc:ServiceConfig {
    topic:config:getAsString("SF_OPPORTUNITY_TOPIC")
}
service sfdcOpportunityListener on sfdcEventListener {
    resource function onEvent(json op) {  
        //convert json string to json
        io:StringReader sr = new(op.toJsonString());
        json|error opportunity = sr.readJson();
        if (opportunity is json) {
            log:printInfo(opportunity.toJsonString());
            //Get the account id from the opportunity
            string accountId = opportunity.sobject.AccountId.toString();
            log:printInfo("Account ID : " + accountId);
            //Create sobject client
            sfdc:SObjectClient sobjectClient = baseClient->getSobjectClient();
            //Get the corresponding account. 
            json|sfdc:Error account = sobjectClient->getAccountById(accountId);
            if (account is json) {
                //extract required fields from the account record
                string accountName = account.Name.toString();
                // Log account information associated with the current opportunity. 
                log:printInfo(account);
                // Add the current opportunity to a DB. 
                sql:Error? result  = addOpportunityToDB(opportunity);
                if (result is error) {
                    log:printError(result.message());
                }
            }

        }
    }
}


function addOpportunityToDB(json opportunity) returns sql:Error? {
    string stageName = opportunity.sobject.StageName.toString(); 
    string accountId = opportunity.sobject.AccountId.toString();
    string id = opportunity.sobject.Id.toString();
    string name = opportunity.sobject.Name.toString();
    
    log:printInfo(id + ":" + accountId + ":" + name + ":" + stageName);
    // The SQL query to insert an Opportunity record to the DB. 
    sql:ParameterizedQuery insertQuery =
            `INSERT INTO ESC_SFDC_TO_DB.Opportunity (Id, AccountId, Name, Description) 
            VALUES (${id}, ${accountId}, ${name}, ${stageName})`;
    // Invoking the MySQL Client to execute the insert operation. 
    sql:ExecutionResult result  =  check mysqlClient->execute(insertQuery);
}