// Static global variables.
integer ADMIN_CHANNEL = 43; // For the admin dialog interfaces.
integer MASTER_CHANNEL = -90; // For giving messages to many objects.
integer REPORT_CHANNEL = -101; // For picking up event / status reports from objects.

// Dynamic global variables.
string SESSION_NAME; // Tracks name of the running session notecard.
list SESSION_LIST; // Tracks list of all possible session notecards.
integer CURRENT_LINE; // Tracks the current line of the running session notecard.

// Displays dialog of session files.
displaySessionList(key userID) { 
    SESSION_LIST = [];
    integer i;
    for (i=0; i<llGetInventoryNumber(INVENTORY_NOTECARD); i++) {
        string notecardName = llGetInventoryName(INVENTORY_NOTECARD,i);
        if (llGetSubString(notecardName,-8,-1) == ".Session") {
            SESSION_LIST += llGetSubString(notecardName,0,-9);
        }
    }
    llDialog(userID,"Which session file do you wish to execute?",SESSION_LIST,ADMIN_CHANNEL);
}

// Processes a line read from a session file.
processData(string data) {
    list dataList = llCSV2List(data);
    string instructionType = llList2String(dataList,0);
    
    // Stop reading notecard for some amount of time.
    if (instructionType == "WAIT") {
        string value = llList2String(dataList,1);
        llSetTimerEvent((float)value);
    }
    
    // Passes message to experiment script in the same prim.
    else if (instructionType == "MASTER") { 
        llMessageLinked(LINK_THIS,0,llList2CSV(llList2List(dataList,1,-1)),NULL_KEY);
    }
    
    // Passes message to object.
    else if (llListFindList(["BUSH","HUD"],[instructionType]) > -1) { 
        llRegionSay(MASTER_CHANNEL,data);
    }
}

// Passes report message to admin. Could be edited to send data to a remove server as well.
report(string data) { 
    llOwnerSay(llGetUnixTime()+","+data);
    //llHTTPRequest({your URL here},[HTTP_METHOD,"POST"],data);
}

// A nice helper function for sending addressed messages to listen events.    
sendNamedMessage(integer channel, string msg, string name) {
    string oldName = llGetObjectName();
    llSetObjectName("TO_"+name);
    llRegionSay(channel, msg);
    llOwnerSay(msg);
    llSetObjectName(oldName);
}
        
default
{
    state_entry()
    {
        integer listen_handle = llListen(ADMIN_CHANNEL,"",llGetOwner(),"");
    }
    
    // Only responds to the touch of whoever rezzed it. If someone wants to be an admin, they should rez the object with this script inside.
    touch_start(integer num) {
        if (llDetectedKey(0) == llGetOwner()) {
            displaySessionList(llDetectedKey(0));
        }
        else {
            llSay(0,"This object is only usable by whoever rezzed it!");
        }
    }
    
    listen(integer channel, string name, key id, string msg) {
        if (llListFindList(SESSION_LIST,[msg]) > -1) {
            SESSION_NAME = msg+".Session";
            state running;
        }
    }
}

state running
{
    state_entry()
    {
        CURRENT_LINE = 0;
        integer listen_handle = llListen(ADMIN_CHANNEL,"",NULL_KEY,"");
        integer report_handle = llListen(REPORT_CHANNEL,"",NULL_KEY,"");
        llSetTimerEvent(0.1); // Start reading the parameter file.
    }
    
    on_rez()
    {
        llResetScript();
    }
    
    // While running, can disable the session or move past the current waiting period.
    touch_start(integer num) {
        if (llDetectedKey(0) == llGetOwner()) {
            llDialog(llDetectedKey(0),SESSION_NAME+ " running. Please choose an option.",["Terminate","Next"],ADMIN_CHANNEL);
        }
        else {
            llSay(0,"This object is only usable by whoever rezzed it!");
        }
    }
    
    link_message(integer linknum, integer channel, string msg, key id) {
        report(msg);
    }  
    
    listen(integer channel, string name, key id, string msg) {
        if (channel == REPORT_CHANNEL) {
            report(msg);
        }
        
        // If terminate chosen, sends out end message to all valid objects.
        else if (msg == "Terminate") { 
            llMessageLinked(LINK_THIS,0,"OFF",NULL_KEY);
            state default;
        }
        
        // Skips to next line in the param file without waiting.
        else if (msg == "Next") { 
            llSetTimerEvent(0.1);
        }
    }
    
    timer() {
        llSetTimerEvent(0.1);
        key nQuery = llGetNotecardLine(SESSION_NAME,CURRENT_LINE);
        CURRENT_LINE++;
    }
    
    dataserver(key query, string data) {
        
        // If the notecard hasn't finished reading...
        if (data != EOF) {
            report(data);
            processData(data);
        }
        
        // Otherwise, end the reading and return to default state.
        else {
            llSetTimerEvent(0.0);
            report("FINISHED");
            state default;
        }
    }
}   