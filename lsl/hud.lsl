// Static global variables
integer GLOBAL_CHANNEL = -90; // For giving messages to many objects.
integer PERSONAL_CHANNEL = -89; // For giving messages to a specific object.
integer REPORT_CHANNEL = -101; // For picking up event / status reports from objects.

// Dynamic global variables
string USER; // Tracks user name
integer HARVESTED; // Tracks the number of berries harvested
float HARVEST_VALUE; // How much is each berry worth?
float PUNISHMENT_COST_USED; // How many berries do I lose if I punish?
float PUNISHMENT_COST_RECEIVED; // How many berries do others lose if I'm punished?
float PAYOFF; // Tracks the current subject payoff.
integer PUNISHMENTS_USED; // Tracks the number of times this user has punished others.
integer PUNISHMENTS_RECEIVED; // Tracks the number of times this user has been punished by others.

// Takes a floating point number and returns a string with the specified number of decimals. Used for converting floats to strings without having lots of trailing decimals.
string fixedPrecision(float input, integer precision)
{
    precision = precision - 7 - (precision < 1);
    if(precision < 0)
        return llGetSubString((string)input, 0, precision);
    return (string)input;
}

// Report information back to the recorder
report(string msg) {
    llRegionSay(REPORT_CHANNEL,(string)llGetUnixTime() + "," + "HUD," + USER + "," + 
                fixedPrecision(PAYOFF,2) + "," + (string)HARVESTED + "," + (string)PUNISHMENTS_USED + "," + (string)PUNISHMENTS_RECEIVED + "," + msg);
}

// A nice helper function for sending addressed messages to listen events.   
sendNamedMessage(integer channel, string msg, string name) {
    string oldName = llGetObjectName();
    llSetObjectName("TO_"+name);
    llRegionSay(channel, msg);
    llSetObjectName(oldName);
}

// Process data from the master object.
processGlobal(string msg) {
    list dataList = llCSV2List(msg);
    string objectType = llList2String(dataList,0);
    
    if (objectType == "HUD") {
        string instructionType = llList2String(dataList,1);
        string val = llList2String(dataList,2);
        
        // Start and stop HUD activity.
        if (instructionType == "ACTIVE") {
            if (val == "1") {
                state active;
            }
            else if (val == "0") {
                state default;
            }
        }
        
        else if (instructionType == "PUNISHMENT_COST_USED") {
            PUNISHMENT_COST_USED = (float)val;
        }
        
        else if (instructionType == "PUNISHMENT_COST_RECEIVED") {
            PUNISHMENT_COST_RECEIVED = (float)val;
        }
        
        else if (instructionType == "HARVEST_VALUE") {
            HARVEST_VALUE = (float)val;
        }
    }
}

// Updates payoff variable based on values of other variables
updatePayoff() {
    PAYOFF = HARVESTED * HARVEST_VALUE - PUNISHMENT_COST_USED * PUNISHMENTS_USED - PUNISHMENT_COST_RECEIVED * PUNISHMENTS_RECEIVED;
}

// Function for resetting all the global variables that track session data.
resetSessionData() {
    HARVESTED = 0;
    PUNISHMENTS_RECEIVED = 0;
    PUNISHMENTS_USED = 0;
    updatePayoff();
}
    

// Function for updating the text display on the prim containing this script.
updateText() {
    llSetText("
        Owned by " + USER + "
        Harvested Berries: " + (string)HARVESTED + "
        Current Payoff: " + fixedPrecision(PAYOFF,2) + "
    ", <1,1,1>, 1.0);
}

default
{
    state_entry() {
        // Initialize the script so it knows which user it is associated with.
        USER = llKey2Name(llGetOwner());
        
        // Define a listen event handler so it responds to messages.
        llListen(GLOBAL_CHANNEL, "", NULL_KEY, "");
        
        // Initialize the text display on prim containing this script
        llSetText("
            Owned by " + USER + "
            Please wait for the experiment to begin!
        ", <1,1,1>, 1.0);
    }
    
    // Triggers when attached to the avatar's HUD.
    on_rez() {
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string msg) {
        processGlobal(msg);
    }
}

state active
{
    state_entry() {
        // Reset variables from previous session.
        resetSessionData();
        
        // Set up listen handlers.
        llListen(GLOBAL_CHANNEL, "", NULL_KEY, "");
        llListen(PERSONAL_CHANNEL, "TO_"+USER, NULL_KEY, "");
        
        updateText();
    }
    
    // Triggers when attached to the avatar's HUD.
    on_rez() {
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string msg) {
        
        if (channel == GLOBAL_CHANNEL) {
            processGlobal(msg);
        }
        
        else if (channel == PERSONAL_CHANNEL) {
            list msgList = llCSV2List(msg);
            string action = llList2String(msgList,0);
            
            if (action == "HARVESTED") {
                HARVESTED++;
                updatePayoff();
                updateText();
            }
            
            else if (action == "PUNISHED") {
                string who = llList2String(msgList,1);
                PUNISHMENTS_RECEIVED++;
                updatePayoff();
                updateText();
                llOwnerSay("You were punished by " + who);
            }
        }
    }
    
    touch_start(integer num) {
        PUNISHMENTS_USED++;
        llRegionSay(GLOBAL_CHANNEL, "PUNISHED," + USER);
        updatePayoff();
        updateText();
        llOwnerSay("You punished the other members of your group!");
    }
}