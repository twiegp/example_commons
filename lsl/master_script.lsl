// Static global variables.
integer ADMIN_CHANNEL = 43; // For the admin dialog interfaces.
integer MASTER_CHANNEL = -90; // For giving messages to many objects.
integer PERSONAL_CHANNEL = -89; // For giving messages to a specific object.
integer REPORT_CHANNEL = -101; // For picking up event / status reports from objects.
integer TIMER_UPDATE = 5; // How often to update berry bushes?

// Static global variables used in determining updates of berry bushes.
list FACTORIAL_LIST = [1,1,2,6,24,120,720,5040,40320];
list PROBABILITY_CUTOFFS;
integer MAX_BERRIES = 9;

// Static global variables given through parameter file.
integer INDIVIDUAL; // Boolean treatment variable that determines if growth rates for berry bushes are determined collectively or individually for each bush.
float GROWTH_RATE; // Base rate of growth, ie. if there's one berry what's the chance of a growth event?
integer INITIAL_BERRIES; // How many berries each bush should start the session with.

// Dynamic global variables.
list BERRY_LIST; // Tracks the number of berries on each bush.

// Gets the probability of some number of success with some number of trials from a binomial distribution with individual success probability equal to individualprob.
float binomialDist(integer successes, integer trials, float individualProb) {
    if (trials >= successes) {
        integer mCx = llList2Integer(FACTORIAL_LIST,trials)/(llList2Integer(FACTORIAL_LIST,successes)*llList2Integer(FACTORIAL_LIST,trials-successes));
        return mCx*llPow(individualProb,successes)*llPow(1-individualProb,trials-successes);
    }
    else {
        return 0;
    }
}

// Parses instructions from the reader script.
processReader(string msg) {
    list dataList = llCSV2List(msg);
    string instructionType = llList2String(dataList,0);
    string val = llList2String(dataList,1);
    
    
    // Start and stop master object activity.
    if (instructionType == "ACTIVE") {
        if (val == "1") {
            state active;
        }
        else if (val == "0") {
            state default;
        }
    }
    
    // Handle different values in the parameter notecard.
    else if (instructionType == "TREATMENT") {
        if (val == "INDIVIDUAL") {
            INDIVIDUAL = 1;
        }
        else {
            INDIVIDUAL = 0;
        }
    }
    
    else if (instructionType == "GROWTH_RATE") {
        GROWTH_RATE = (float)val;
        
        // Generate probability cutoffs on growth.
        PROBABILITY_CUTOFFS = [];
        integer i;
        for(i=0;i<MAX_BERRIES*(MAX_BERRIES-1);i++) {
            PROBABILITY_CUTOFFS += binomialDist(i%MAX_BERRIES,MAX_BERRIES-i/MAX_BERRIES-1,GROWTH_RATE*(i/MAX_BERRIES+1)/8.0);
        }
    }
    
    else if (instructionType == "N_BUSHES") {
        BERRY_LIST = [];
        integer n_bushes = (integer)val;
        integer i;
        for (i=0; i<n_bushes; i++) {
            BERRY_LIST += INITIAL_BERRIES;
        }
    }
    
    else if (instructionType == "INITIAL_BERRIES") {
        integer i;
        for (i=0; i<llGetListLength(BERRY_LIST); i++) {
            BERRY_LIST = llListReplaceList(BERRY_LIST,[(integer)val],i,i);
        }
    }
    
    else if (instructionType == "OFF") {
        llRegionSay(MASTER_CHANNEL,"BUSH,ACTIVE,0");
        llRegionSay(MASTER_CHANNEL,"HUD,ACTIVE,0");
        state default;
    }
}

// Report information back to the recorder
report(string msg) {
    llMessageLinked(LINK_THIS, REPORT_CHANNEL, (string)llGetUnixTime() + "," + llGetObjectName() + "," + msg, NULL_KEY);
}

// A nice helper function for sending addressed messages to listen events.   
sendNamedMessage(integer channel, string msg, string name) {
    string oldName = llGetObjectName();
    llSetObjectName("TO_"+name);
    llRegionSay(channel, msg);
    llSetObjectName(oldName);
}

// Update the number of berries on each bush.
updateBushes() {
    list growList;
    integer totalGrown;
    integer i;
    
    // Iterate over all the bushes and determine how many berries should grow for each bush.
    for(i=0; i<llGetListLength(BERRY_LIST); i++) {
        integer currentNum = llList2Integer(BERRY_LIST,i);
        integer growNum = 0;
        if (currentNum > 0 && currentNum < 9) {
            float myRand = llFrand(1);
            integer j;
            for (j=(currentNum-1)*MAX_BERRIES;j<currentNum*MAX_BERRIES;j++) {
                float chance = llList2Float(PROBABILITY_CUTOFFS,j);
                if (myRand < chance) {
                    growNum = j%MAX_BERRIES;
                    totalGrown += growNum;
                    jump foundGrow;
                }
                else {
                    myRand -= chance;
                }
            }
        }
        @foundGrow;
        growList += growNum;
    }
    
    // For the individual treatment, just update the berry list by adding on the grow list.
    if (INDIVIDUAL == 1) {
        for(i=0; i<llGetListLength(BERRY_LIST); i++) {
            BERRY_LIST = llListReplaceList(BERRY_LIST,[llList2Integer(BERRY_LIST,i)+llList2Integer(growList,i)],i,i);
        }
    }
    
    // For the group treatment, randomly allocate berries to bushes that can take them one at a time. This is not a very efficient algorithm.
    else {
        list indexList = [];
        for(i=0; i<llGetListLength(BERRY_LIST); i++) {
            indexList += i;
        }
        
        // Shuffle indices, then try to add a berry at each index until a valid bush is found.
        for(i=0; i<totalGrown; i++) {
            integer j;
            list shuffledIndices = llListRandomize(indexList,1);
            for(j=0; j<llGetListLength(shuffledIndices); j++) {
                integer thisIndex = llList2Integer(shuffledIndices,j);
                integer currentBerries = llList2Integer(BERRY_LIST,thisIndex);
                if (currentBerries < MAX_BERRIES) {
                    BERRY_LIST = llListReplaceList(BERRY_LIST, [currentBerries + 1], thisIndex, thisIndex);
                    jump foundIndex;
                }
            }
            @foundIndex;
        }
    } 
    
    // Take the new berry list, and relay it to bushes. Also report it.
    string treestring = llDumpList2String(BERRY_LIST,";");
    llRegionSay(MASTER_CHANNEL,"BUSH,GROW,"+treestring);
    report("BUSH,GROW,"+treestring);
}

default
{
    state_entry()
    {
    }
    
    link_message(integer sender_num, integer num, string msg, key id) {
        processReader(msg);
    }
}

state active
{
    state_entry()
    {
        llListen(PERSONAL_CHANNEL,"TO_MASTER",NULL_KEY,"");
        llSetTimerEvent(TIMER_UPDATE);
        updateBushes();
    }
    
    // Processes instructions from session file.
    link_message(integer sender_num, integer num, string msg, key id) {
        processReader(msg);
    }
    
    // Listens for things happening in the experiment and responds to them.
    listen(integer channel, string name, key id, string msg) {
        list msgList = llCSV2List(msg);
        string msgType = llList2String(msgList,0);
        
        // Decrement the berry list in response to a harvest event.
        if (msgType == "HARVESTED") {
            integer index = (integer)llList2String(msgList,1);
            integer current_berries = llList2Integer(BERRY_LIST,index);
            BERRY_LIST = llListReplaceList(BERRY_LIST,[current_berries-1],index,index);
        }
    }
    
    // Perform a periodic update of all the berry bushes to see whether they should grow new berries.
    timer() {
        updateBushes();
    }
}