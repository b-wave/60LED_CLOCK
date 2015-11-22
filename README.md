60LED_CLOCK
===========

Program the 360 Clock 


The master BLOG is here: http://brainwave57.blogspot.com/2012/09/its-about-time-hacking-360-clock.html

Text below for those who don't want to go there... It's About Time - Hacking the 360 Clock 

Clocks With Radios... Projects get done in the Radio Ranch from time to time. My in-law father is really into clocks of all kinds. We are working on an extremely obfuscated clock linked to the NIST clock in Ft. Collins, Colorado...just having several microprocessors working to extract and uniquely display and chime in the time-of-day. (I'll post that project someday) Unfortunately, this project was far form complete to give for his holiday gift but I came across the:

Which has 60 LEDs much like my obfuscated time piece. http://www.pictronicsonline.com/Clock360WWVB/Description.htm

(BTW ~ my network security feature says this may b3e a malicious link...I never had any problems) I thought, cool, I will just buy a kit...build it and take pressure off the obfuscated clock. 

The PCB for this is HUGE! The obfuscated clock will be way smaller - to be contained in an anniversary clock dome

Along with these displays.

The build went OK. The layout was a little on the amateurish side but mostly OK. The voltage regulator has this huge heat sink on it. ( I fixed this problem as well) The first thing I did not like was all the LEDs came on each minute. I though an option to reduce to a single LED, would be better. They had this cascade mode that was pretty cool but again 60 LEDs were a bit much. 

Of course, I wanted changes to the behavior and found some interesting defects. Still, Brent from MyPictronics was very helpful in getting the changes to me... although they were updates he burned into a PIC, no source code or programmable files... I guess I don't blame him, it is his property and programming. 

Then there was an annoying issue he could not solve... the clock kept getting stuck in this error mode that he had never seen:

All he could offer was my power supply was bad... We went back an fourth with several iterations...

From: MyPictronics MyPictronics@aol.com Sent: Sun, August 19, 2012 9:23:47 AM Subject: RE: 360 clock w/WWB Sync Questions

Attached is the updated manual for the new feature requests. Clear as mud but let me know if you have any questions. I tried to test everything but always miss something – let me know if you have any problems. Brent

Sent: Tuesday, September 04, 2012 10:33 AM To: MyPICTronics@aol.com Subject: 360 clock w/WWVB Sync Options - Update

Hi Brent!

Thanks for the updated chip. The LED display with the burst mode looks Awesome! Even better than I thought it would, and it keeps the voltage regulator running at a better temperature as well... very nice.

From: MyPictronics MyPictronics@aol.com Sent: Thu, September 6, 2012 8:10:51 AM Subject: RE: 360 clock w/WWVB Sync Options - Update

--> 

I have been running non-stop and haven’t seen this problem.

What are the power ratings of your adapter (output voltage and current)? I have only seen this happen in the past with an insufficient power adapter which would eventually cause it to shutdown and/or lockup.

Sent: Wednesday, September 05, 2012 3:26 PM To: MyPictronics Subject: Re: 360 clock w/WWVB Sync Options - Update

Hi Brent, Yes it was a little bent - at least it was only one side of pins this time. 

I have not seen it on manual sync - it happens all the time now on normal operation -- it stops running with these codes after an hour or so. 

We also tried powering up with the mode switch and it gives the same result. We will try again with auto Sync off as it seems to happen during re-sync, but we have not seen exactly when it happens. 

It seems Diag mode is always on because when I do a manual Sync the S, P, 1, 0 is showing and it can successfully sync...it did after I powered with the MODE key...and it also went back to the original Burst mode pattern.

From: MyPictronics MyPictronics@aol.com Sent: Wed, September 5, 2012 8:21:13 AM Subject: RE: 360 clock w/WWVB Sync Options - Update

Hope it made it without the PO crushing it again. They ignore the hand stamp sometimes.

1) Did this happen due to a manual sync? Might have been due to the change over. 2) Did you try a reset (Press and hold mode switch during power-up)?

Are these codes happening during normal operation or during resync? I haven’t seen this.

Here are some issues we have observed since last week:
1.
The date rollover from 8/31/12 and 9/01/12 had a couple issues; the month rolled to 00/01/12 and it looks like the month went into the hours position as the clock was reading "9:01" after midnight. Everything seems to have corrected itself by morning with a re-sync. during the night.

2.
The clock keeps halting with some codes like "P2-4" , "P3-2" on the display. I tried restarting the clock with diag. mode off, not holding the select button but it seems to have no effect.

Thanks Brent! 


We really appreciate the quick response and look forward to trying these new features out!

Hi Brent -

We were using a high current linear supply, it has been on an Astron 12A supply RS12A 12 so, Just in case there was some issue I swapped it to a 2A lab bench power supply... (see attached) It does the same thing. I tried at 8, 9, 10 and 12 V settings the current draw is minimal and even when I use the old "all LED on" display and in any case is not causing the supply to current limit. 

I did a few more experiments this weekend and here is what I see:
1.
This occurs during resync, at the end with a good SYNC and after all 6 frames are completed- I saw it for the first time right at the end of auto sync this morning... It does not happen all of the time. I can see syncing and force syncs OK sometimes so it is not a hard failure. The clock ran all Saturday night until late morning when I just happened to be around to see the first failure. 

2.
It can also happen when we do a manual resync... I got it to freeze 5 out of 5 times even after a full restart. I tried turning diag mode off and it still stops on that P3-5 display. Once it is in this mode it always happens. The signal was good and it looked like it was about to update when the crash occurs. 

3.
When I put the OLD PIR software chip in it does not freeze even with the same supplies and same signal strength. I did see that "P3-5" display briefly before it updated once but the clock was still running and it took the new tile OK. Of course this version only runs 15mins so it is hard to compare the two versions but when I put the second chip back in the failures repeated immediately. Then the signal was too weak to get anymore syncs. 

4.
After what you said, and knowing these supplies are pretty good, I thought it may be the voltage regulator so I swapped with a new 5V regulator . it still locks up. I seems to be locking up as it should be writing to the clock chip so I looked carefully around that chip to see if there may be a solder issue - but did not see anything.


Let me know if you think of anything else to try. I don't know if the chip got damaged by its shipping adventure, I had to straighten the pins to plug it in ( see attached photo)

So... The Hack Began!

Really he was pretty responsive, I got tired of the back and forth, it was not going to work out. We ended with these fixes left it at the solution was to send the clock to him...with all the hardware mods (...Improvements, IMO) done on his board he was going to blame these. To be fair, he had no idea that have, well, decades of experience building and designing far more complex boards. 

So, time to break out the MICROCHIP IDE, hoist up the old skull and x-bones and let the fun begin.
