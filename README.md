# SM-SaveLoc
Retain position, angle, and velocity data  
See include file for plugin integration  

## Commands
`sm_practice` - Enable practice mode - only required if cvar is set  
`sm_sl` - Save loc  
`sm_tl` - Tele loc  
`sm_ml` - Loc menu (Allows chosing from one of 10 recent saves)  
`sm_rl` - Remove Loc - Opens menu to select a save to remove  

## ConVars
`sm_saveloc_requireenable "1"` // Require the client activate a toggle before using commands?  
`sm_saveloc_allowother "1"` // Allows clients to use other players' saves?  
`sm_saveloc_forceteam "1"` // Only allow client to use saves from players on their own team?  
`sm_saveloc_forceclass "1"` // Only allow clients to use saves from players of their own class? (TF2)  
`sm_saveloc_wipeonteam "1"` // Should the plugin wipe saves on team change?  
`sm_saveloc_wipeonclass "1"` // Should the plugin wipe saves on class change?  

Examples of plugin integration:  
[Example 1](https://github.com/JoinedSenses/TF2-ECJ-JumpAssist/blob/1ba05f6ff59c79afb1d6ee0bdbf6771c50b7444c/scripting/jumpassist.sp#L260)  
[Example 2](https://github.com/JoinedSenses/TF2-ECJ-JumpAssist/blob/1ba05f6ff59c79afb1d6ee0bdbf6771c50b7444c/scripting/jumpassist.sp#L1040-L1043)  
[Example 3](https://github.com/JoinedSenses/TF2-ECJ-JumpAssist/blob/1ba05f6ff59c79afb1d6ee0bdbf6771c50b7444c/scripting/jumpassist/sl.sp)  

![Menu Image](https://i.imgur.com/UhW4WxB.png)
