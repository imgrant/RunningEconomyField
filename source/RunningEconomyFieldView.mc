using Toybox.WatchUi as Ui;

class RunningEconomyFieldView extends Ui.SimpleDataField {

	hidden var uRestingHeartRate 	= 60;
	
	hidden var mTimerRunning = false;

	hidden var mPrevElapsedDistance = 0;

	hidden var mLaps 					 = 1;
	hidden var mLastLapDistMarker 		 = 0;
    hidden var mLastLapTimeMarker 		 = 0;
    hidden var mLapHeartRateAccumulator  = 0;

	hidden var mRecentHR = new [30];
	hidden var curPos;
	
	hidden var mLastLapTimerTime 		= 0;
	hidden var mLastLapElapsedDistance 	= 0;
	hidden var mLastLapEconomy			= 0;

	hidden var mLastNDistanceMarker = 0;
	hidden var mLastNEconomySmooth	= 0;
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
        
        for (var i = 0; i < mRecentHR.size(); ++i) {
            mRecentHR[i] = 0.0;
        }
        curPos = 0;
    }


    // The given info object contains all the current workout
    // information. Calculate a value and return it in this method.
    function compute(info) {
    	if (mTimerRunning) {  //! We only do calculations if the timer is running (distance isn't accumulated otherwise)
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
	    	
            var idx = curPos % mRecentHR.size();
            curPos++;
            mRecentHR[idx] = mCurrentHeartRate;

			//! Running economy: http://fellrnr.com/wiki/Running_Economy
			//! Averaged over the last 30 seconds, exponential smoothing applied on top,
			//! decay factor alpha set at 2/(N+1); N=8, alpha and 1-alpha have been pre-computed
			var mLastNAvgHeartRate = 0.0;
			if (mTicker < 30) {
				mLastNAvgHeartRate = getNAvg(mRecentHR, idx+1, mTicker);
			} else {
				mLastNAvgHeartRate = getAverage(mRecentHR);
			}
			var mLastNEconomy = 0.0;
			if (mLastNElapsedDistance > 0) {
				var t = (mTicker < 30) ? mTicker / 60.0 : 0.5;
				mLastNEconomy = ( 1 / ( ((mLastNAvgHeartRate - uRestingHeartRate) * t) / (mLastNElapsedDistance / 1609.344) ) ) * 100000;
			}
			mLastNEconomySmooth = (0.222222 * mLastNEconomy) + (0.777777 * mLastNEconomySmooth);

	        mEconomyField.setData(mLastNEconomySmooth.toNumber());

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
        return mLastNEconomySmooth.toNumber();
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
		mLastNEconomySmooth	 = 0;
		mAverageEconomy		 = 0;
		mLapEconomy			 = 0;
		
		mTicker 	= 0;
		mLapTicker	= 0;
		
		for (var i = 0; i < mRecentHR.size(); ++i) {
            mRecentHR[i] = 0.0;
        }
        curPos = 0;		
    }
    
    
    function getAverage(a) {
        var count = 0;
        var sum = 0.0;
        for (var i = 0; i < a.size(); ++i) {
            if (a[i] > 0.0) {
                count++;
                sum += a[i];
            }
        }
        if (count > 0) {
            return sum / count;
        } else {
            return null;
        }
    }


    function getNAvg(a, curIdx, n) {
        var start = curIdx - n;
        if (start < 0) {
            start += a.size();
        }
        var count = 0;
        var sum = 0.0;
        for (var i = start; i < (start + n); ++i) {
            var idx = i % a.size();
            if (a[idx] > 0.0) {
                count++;
                sum += a[idx];
            }
        }
        if (count > 0) {
            return sum / count;
        } else {
            return null;
        }
    }

}