/* Licensed under The MIT License (MIT), see license.txt*/
package tanjent.tanjentxm;

/** <p>
 * Holds a MONO sample in FixedPoint format. Loops are always forward which means that bidirectional
 * looping samples will double in size by the loop length.
 * </p>
 * @author Jonas Murman */
class XMSample
{
	/// Cubic interpolation requires a prior sample, offset all sample data by this offset
	public static var SAMPLE_START:Int = 1;
	
	/// Number of samples
	public var dataFPLength:Int;
	/// Sample data stored in FP format
	public var dataFP:Array <Int>;	

	public var sampleLoopStartPosition:Int;
	public var sampleLoopEndPosition:Float;
	public var sampleLoopLength:Float;

	public var volume:Int;
	public var finetune:Int;
	public var panning:Int;
	public var relativeNote:Int;
	
	public function new() 
	{		
		this.dataFPLength = 0;
		this.dataFP = new Array<Int>();

		this.volume = 0;
		this.finetune = 0;
		this.panning = 0;
		this.relativeNote = 0;		
		
		this.sampleLoopStartPosition = 0;
		this.sampleLoopEndPosition = 0.0;
		this.sampleLoopLength = 0.0;			
	}

	/**
	 * Fixes the sample data for interpolation and bidirectional looping. This must be called before
	 * the sample is used.
	 * @param biDirectionalLoop indicates if loop is a bi-directional loop (ping-pong loop)
	 */
	public function fixForInterpolation(biDirectionalLoop:Bool)
	{
		// no sample data, or invalid sample length?
		if (this.dataFPLength <= 0 || this.dataFP == null) {		
			this.dataFP = new Array<Int>();
		
			// create a silent sample
			this.dataFP[0] = 0;
			this.dataFP[1] = 0;
			this.dataFP[2] = 0;
			this.dataFP[3] = 0;
			this.dataFP[4] = 0;
			this.dataFPLength = 5;	
			
			// set loop points
			this.sampleLoopStartPosition = 0;
			this.sampleLoopEndPosition = 0.0;
			this.sampleLoopLength = 0.0;

			// done
			return;			
		}
		
		// sanity check loop points
		if (this.sampleLoopStartPosition < 0) this.sampleLoopStartPosition = 0;
		if (this.sampleLoopEndPosition < 0) this.sampleLoopEndPosition = 0;		
		if (this.sampleLoopStartPosition > this.sampleLoopEndPosition) 
		{
			this.sampleLoopStartPosition = this.dataFPLength;
			this.sampleLoopEndPosition = this.dataFPLength;			
		}		
		if (this.sampleLoopStartPosition > this.dataFPLength) this.sampleLoopStartPosition = this.dataFPLength;
		if (this.sampleLoopEndPosition > this.dataFPLength) this.sampleLoopEndPosition = this.dataFPLength;	
				
		// calculate loop length
		this.sampleLoopLength = this.sampleLoopEndPosition - this.sampleLoopStartPosition;		
		
		// no loop or forward loop
		if (biDirectionalLoop == false || this.sampleLoopLength == 0)
		{			
			var newDataFPLength:Int = XMSample.SAMPLE_START + this.dataFPLength + 5;
			var newDataFP:Array<Int> = new Array<Int>();
			
			// fill start with first sample
			var p:Int = 0;
			for (i in 0 ... XMSample.SAMPLE_START)
			{
				newDataFP[p] = this.dataFP[0];				
				p++;
			}
			
			// copy old data to new
			for (i in 0 ... this.dataFPLength)
			{
				newDataFP[p] = this.dataFP[i];
				p++;
			}
			
			// fill end with last sample
			for (i in 0 ... 5)
			{	
				newDataFP[p] = this.dataFP[this.dataFPLength - 1];
				p++;
			}
			
			// replace data
			this.dataFPLength = newDataFPLength;
			this.dataFP = newDataFP;
			
			// move loop points
			this.sampleLoopStartPosition += XMSample.SAMPLE_START;
			this.sampleLoopEndPosition += XMSample.SAMPLE_START;
			
			return;
		}
		
		// bidirectional loop
		var newDataFPLength:Int = Std.int(XMSample.SAMPLE_START + this.dataFPLength + this.sampleLoopLength + 5);
		var newDataFP:Array<Int> = new Array<Int>();		
				
		// fill start with first sample
		var p:Int = 0;
		for (i in 0 ... XMSample.SAMPLE_START)
		{
			newDataFP[p] = this.dataFP[0];				
			p++;
		}		
		
		// copy old data to new, up to loop end position
		for (i in 0 ... Std.int(this.sampleLoopEndPosition))
		{
			newDataFP[p] = this.dataFP[i];
			p++;
		}
		
		// fill loop backwards
		var sp:Int = Std.int(this.sampleLoopEndPosition) - 1;
		for (i in 0 ... Std.int(this.sampleLoopLength) - 1)
		{
			newDataFP[p] = this.dataFP[sp];
			p++;
			sp--;
		}
		
		// fill loop forwards again
		sp = Std.int(this.sampleLoopStartPosition);
		for (i in 0 ... Std.int(this.dataFPLength - this.sampleLoopEndPosition) + 1)
		{
			newDataFP[p] = this.dataFP[sp];
			p++;
			sp++;
		}
	
		// fill end with last sample
		for (i in 0 ... 5)
		{
			newDataFP[p] = this.dataFP[sp];
			p++;
		}			
			
		// replace data
		this.dataFPLength = newDataFPLength;
		this.dataFP = newDataFP;
			
		// move loop points
		this.sampleLoopStartPosition += XMSample.SAMPLE_START;
		this.sampleLoopEndPosition += XMSample.SAMPLE_START;
		this.sampleLoopEndPosition += this.sampleLoopLength;
		
		// update loop length
		this.sampleLoopLength += this.sampleLoopLength;
	}
		
	/**
	 * Wraps an (out of bounds) samplePosition within loop bounds
	 * @param samplePosition the current sample position
	 * @return the wrapped sample position or -1 if there's no more data available (there's no loop defined)
	 */
	public inline function getWrappedSamplePosition(samplePosition:Float):Float
	{
		// assume no more samples
		var retValue:Float = -1.0;

		// wrap loop
		if (this.sampleLoopStartPosition < this.sampleLoopEndPosition)
		{
			samplePosition -= this.sampleLoopStartPosition;
			retValue = this.sampleLoopStartPosition + (samplePosition % this.sampleLoopLength);
		}

		return retValue;
	}

}