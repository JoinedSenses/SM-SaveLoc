# SM-SaveLoc
Retain position, angle, and velocity data  
See include file for plugin integration  

## Commands
`sm_practice` - Enable practice mode - only required if cvar is set  
`sm_sl` - Save loc  
`sm_tl` - Tele loc  
`sm_ml <optional:playerName>` - Loc menu (Allows chosing from one of 10 recent saves)  
`sm_rl` - Remove Loc - Opens menu to select a save to remove  

## ConVars
`sm_saveloc_requireenable "1"` // Require the client activate a toggle before using commands?  
`sm_saveloc_onground "1"` // Require the client to be on the ground while enabling practice toggle?  
`sm_saveloc_restoreontoggle "1"` // Save and restore client location on toggle of practice command?  
`sm_saveloc_allowother "1"` // Allows clients to use other players' saves?  
`sm_saveloc_forceteam "1"` // Only allow client to use saves from players on their own team?  
`sm_saveloc_forceclass "1"` // Only allow clients to use saves from players of their own class? (TF2)  
`sm_saveloc_wipeonteam "1"` // Should the plugin wipe saves on team change?  
`sm_saveloc_wipeonclass "1"` // Should the plugin wipe saves on class change?  

### Example of plugin integration:  
[Ref 1 - Checking library](https://github.com/JoinedSenses/TF2-ECJ-JumpAssist/blob/336fa59af75a2136c69e414f81416543c1ffb8bf/scripting/jumpassist.sp#L293-L295)  
[Ref 2 - Using a native](https://github.com/JoinedSenses/TF2-ECJ-JumpAssist/blob/1ba05f6ff59c79afb1d6ee0bdbf6771c50b7444c/scripting/jumpassist.sp#L1040-L1043)  
[Ref 3 - Using a forward](https://github.com/JoinedSenses/TF2-ECJ-JumpAssist/blob/9b6ee08c22a6425bf3cccafd957bc98444f7c375/scripting/jumpassist/sl.sp#L7-L29)  

![Menu Image](https://i.imgur.com/UhW4WxB.png)
