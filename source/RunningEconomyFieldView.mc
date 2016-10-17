using Toybox.WatchUi as Ui;

class RunningEconomyFieldView extends Ui.SimpleDataField {

	hidden var uRestingHeartRate 	= 60;
	
	hidden var mTimerRunning = false;

	hidden var mPrevElapsedDistance = 0;

	hidden var mLaps 					 = 1;
	hidden var mLastLapDistMarker 		 = 0;
    hidden var mLastLapTimeMarker 		 = 0;
    hidden var mLapHeartRateAccumulator  = 0;

	hidden var mLastLapTimerTime 		= 0;
	hidden var mLastLapElapsedDistance 	= 0;
	hidden var mLastLapEconomy			= 0;

	hidden var mLastNDistanceMarker = 0;
	hidden var mLastNAvgHeartRate 	= 0;
	hidden var mLastNEconomy 		= 0;
	hidden var mAverageEconomy		= 0;
	hidden var mLapEconomy			= 0;
	
	hidden var mTicker 		= 0;
	hidden var mLapTicker	= 0;
	
	hidden var mEconomyField 		= null;
	hidden var mAverageEconomyField = null;
	hidden var mLapEconomyField 	= null;
	
    // Set the label of the data field here.
    function initialize() {
        SimpleDataField.initialize();
        label = "Economy";
        
        var mProfile 		= UserProfile.getProfile();
 		uRestingHeartRate 	= mProfile.restingHeartRate;
 		
 		mEconomyField 		 = createField("running_economy", 0, FitContributor.DATA_TYPE_UINT16, { :mesgType=>FitContributor.MESG_TYPE_RECORD });
        mAverageEconomyField = createField("average_economy", 1, FitContributor.DATA_TYPE_UINT16, { :mesgType=>FitContributor.MESG_TYPE_SESSION });
        mLapEconomyField 	 = createField("lap_economy", 	  2, FitContributor.DATA_TYPE_UINT16, { :mesgType=>FitContributor.MESG_TYPE_LAP });
        
        mEconomyField.setData(0);
        mAverageEconomyField.setData(0);
        mLapEconomyField.setData(0);
    }


    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    function compute(info) {
    	if (mTimerRunning) {  //! We only do calculations if the timer is running
    		mTicker++;
	        mLapTicker++;

    		var mElapsedDistance 		= (info.elapsedDistance != null) ? info.elapsedDistance : 0.0;
	    	var mDistanceIncrement 		= mElapsedDistance - mPrevElapsedDistance;
	    	var mLapElapsedDistance 	= mElapsedDistance - mLastLapDistMarker;
	    	var mLastNElapsedDistance 	= mElapsedDistance;
	    	if (mTicker > 30) {
	    		mLastNElapsedDistance = mElapsedDistance - mLastNDistanceMarker;
				mLastNDistanceMarker += mDistanceIncrement;
	    	}
	    	var mLapTimerTime = (info.timerTime != null) ? info.timerTime - mLastLapTimeMarker : 0.0;
	    	var mCurrentHeartRate		= (info.currentHeartRate != null) ? info.currentHeartRate : 0;
	    	var mAverageHeartRate		= (info.averageHeartRate != null) ? info.averageHeartRate : 0;
	    	mLapHeartRateAccumulator   += mCurrentHeartRate;
	    	var mLapHeartRate 			= (mLapHeartRateAccumulator / mLapTicker).toNumber();	

			//! Running economy: http://fellrnr.com/wiki/Running_Economy
			//! Averaged over the last 30 seconds, with the caveat that an exponential moving average
			//! is used for the heart rate data (saves memory versus storing N HR values)
			//! \-> Decay factor alpha set at 2/(N+1); N=30, alpha and 1-alpha have been pre-computed
	        if (mLastNAvgHeartRate == 0.0) {
	        	mLastNAvgHeartRate = mCurrentHeartRate;
	        	mLastNEconomy = 0.0;
	        } else {
	        	mLastNAvgHeartRate = (0.064516 * mCurrentHeartRate) + (0.935484 * mLastNAvgHeartRate);
				if (mLastNElapsedDistance > 0) {
					var t = (mTicker < 30) ? mTicker / 30.0 : 0.5;
					mLastNEconomy = ( 1 / ( ((mLastNAvgHeartRate - uRestingHeartRate) * t) / (mLastNElapsedDistance / 1609.344) ) ) * 100000;
				}
	        }
	        mEconomyField.setData(mLastNEconomy.toNumber());

	        if (mAverageHeartRate > uRestingHeartRate
	        	&& mElapsedDistance > 0) {
	        	mAverageEconomy = ( 1 / ( ( (mAverageHeartRate - uRestingHeartRate) * (info.timerTime / 60000.0) ) / (mElapsedDistance / 1609.344) ) ) * 100000;
	        }
	        mAverageEconomyField.setData(mAverageEconomy.toNumber());

	        if (mLapHeartRate > uRestingHeartRate
	        	&& mLapElapsedDistance > 0) {
	        	mLapEconomy = ( 1 / ( ( (mLapHeartRate - uRestingHeartRate) * (mLapTimerTime / 60000.0) ) / ( mLapElapsedDistance / 1609.344) ) ) * 100000;
	        }
	        mLapEconomyField.setData(mLapEconomy.toNumber());
	        
	        mPrevElapsedDistance = mElapsedDistance;
    	}	
        return mLastNEconomy.toNumber();
    }
    
    
    //! Store last lap quantities and set lap markers
    function onTimerLap() {
    	var info = Activity.getActivityInfo();

    	mLastLapTimerTime			= (info.timerTime - mLastLapTimeMarker) / 1000;
    	mLastLapElapsedDistance		= (info.elapsedDistance != null) ? info.elapsedDistance - mLastLapDistMarker : 0;
    	mLastLapEconomy				= mLapEconomy;
		
    	mLaps++;
    	mLapTicker = 0;
    	mLastLapDistMarker 			= info.elapsedDistance;
    	mLastLapTimeMarker 			= info.timerTime;
    	mLapHeartRateAccumulator 	= 0;
    	mLapEconomy					= 0;
    	
    }

    //! Timer transitions from stopped to running state
    function onTimerStart() {
    	mTimerRunning = true;
    }


    //! Timer transitions from running to stopped state
    function onTimerStop() {
    	mTimerRunning = false;
    }


    //! Timer transitions from paused to running state (i.e. resume from Auto Pause is triggered)
    function onTimerResume() {
    	mTimerRunning = true;
    }


    //! Timer transitions from running to paused state (i.e. Auto Pause is triggered)
    function onTimerPause() {
    	mTimerRunning = false;
    }


    //! Current activity is ended
    function onTimerReset() {
		mPrevElapsedDistance = 0;

		mLaps 					  = 1;
		mLastLapDistMarker 		  = 0;
	    mLastLapTimeMarker 		  = 0;
	    mLapHeartRateAccumulator  = 0;

		mLastLapTimerTime 		= 0;
		mLastLapElapsedDistance = 0;
		mLastLapEconomy			= 0;

		mLastNDistanceMarker = 0;
		mLastNAvgHeartRate 	 = 0;
		mLastNEconomy 		 = 0;
		mAverageEconomy		 = 0;
		mLapEconomy			 = 0;
		
		mTicker 	= 0;
		mLapTicker	= 0;
    }

}