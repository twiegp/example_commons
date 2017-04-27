// Communication Information
integer HUD_CHANNEL = -108;
integer MASTER_CHANNEL = -109;

// Bush configuration
integer INITIAL_BERRIES = 9;
float GROWTH_RATE = 0.02;
float MAX_PICK_DISTANCE = 5.0;

// Bush state information
integer CURRENT_BERRIES;

// Helper function for sending well-addressed messages to different sets of recipients  
sendNamedMessage(integer channel, string msg, string name) {
    string oldName = llGetObjectName();
    llSetObjectName("TO_"+name);
    llRegionSay(channel, msg);
    llSetObjectName(oldName);
}


default
{
    state_entry() {
        // Initialize listen handlers to respond to messages that meet this criteria via the listen event.
        llListen(MASTER_CHANNEL, "", NULL_KEY, "");
    }  
    
    listen(integer channel, string name, key id, string msg) {
        if (msg == "Start") {
            state active;
        }
    }
}

state active
{
    state_entry() {
        CURRENT_BERRIES = INITIAL_BERRIES;
        
        // Initialize listen handlers to respond to messages that meet this criteria via the listen event.
        llListen(MASTER_CHANNEL, "", NULL_KEY, "");
        
        // Initialize a timer to check whether new berries should grow every 5 seconds.
        llSetTimerEvent(5);
    }
    
    listen(integer channel, string name, key id, string msg) {
        if (msg == "Stop") {
            state default;
        }
    }
    
    // When touched by an avatar within range, if the bush has berries decrement the number of berries and send a message to the avatar who touched the berry.
    touch_start(integer num) {
        if (CURRENT_BERRIES > 0 && llVecDist(llDetectedPos(0), llGetPos())< MAX_PICK_DISTANCE) {
            CURRENT_BERRIES--;
            sendNamedMessage(HUD_CHANNEL, "PICKED", llDetectedName(0));
        }
    }
}