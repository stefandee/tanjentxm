/* Licensed under The MIT License (MIT), see license.txt*/
package tanjent.tanjentxm;

/** <p>
 * Holds a complete XM-instrument (envelopes, key mappings, samples).
 * </p>
 * @author Jonas Murman */
class XMInstrument
{
	
	public var numberOfSamples:Int;
	public var samples:Array<XMSample>;	
	public var noteToSampleIndex:Array<Int>;

	public static var ENVELOPE_MAXIMUM_POINTS:Int = 12;
	
	public var volumeEnvelopeEnabled:Bool;
	public var volumeEnvelopeSustainEnabled:Bool;
	public var volumeEnvelopeLoopEnabled:Bool;
	public var volumeEnvelopeNumberOfPoints:Int;	
	public var volumeEnvelopeSustainPointIndex:Int;
	public var volumeEnvelopeTicks:Array<Int>;
	public var volumeEnvelopeValues:Array<Int>;		
	public var volumeEnvelopeLoopStartPointIndex:Int;
	public var volumeEnvelopeLoopEndPointIndex:Int;
		
	public var panningEnvelopeEnabled:Bool;
	public var panningEnvelopeSustainEnabled:Bool;
	public var panningEnvelopeLoopEnabled:Bool;
	public var panningEnvelopeNumberOfPoints:Int;
	public var panningEnvelopeSustainPointIndex:Int;
	public var panningEnvelopeTicks:Array<Int>;
	public var panningEnvelopeValues:Array<Int>;	
	public var panningEnvelopeLoopStartPointIndex:Int;
	public var panningEnvelopeLoopEndPointIndex:Int;
	
	public var vibratoType:Int;
	public var vibratoSweep:Int;
	public var vibratoDepth:Int;
	public var vibratoRate:Int;

	public static var FADEOUT_MAX:Int = 65535;	
	public var fadeout:Int;
	
	public function new() 
	{

		this.numberOfSamples = 0;
		this.samples = new Array<XMSample>();
		this.noteToSampleIndex = new Array<Int>();	
		for (i in 0 ... XMModule.NUMBER_OF_NOTES)
		{
			this.noteToSampleIndex[i] = 0;
		}
		
		this.volumeEnvelopeEnabled = false;
		this.volumeEnvelopeSustainEnabled = false;
		this.volumeEnvelopeLoopEnabled = false;		
		this.volumeEnvelopeNumberOfPoints = 0;
		this.volumeEnvelopeSustainPointIndex = 1;
		this.volumeEnvelopeLoopStartPointIndex = 1;
		this.volumeEnvelopeLoopEndPointIndex = 1;
		this.volumeEnvelopeTicks = new Array<Int>();
		this.volumeEnvelopeValues = new Array<Int>();		
			
		this.panningEnvelopeEnabled = false;
		this.panningEnvelopeSustainEnabled = false;
		this.panningEnvelopeLoopEnabled = false;	
		this.panningEnvelopeNumberOfPoints = 0;
		this.panningEnvelopeSustainPointIndex = 1;
		this.panningEnvelopeLoopStartPointIndex = 1;
		this.panningEnvelopeLoopEndPointIndex = 1;		
		this.panningEnvelopeTicks = new Array<Int>();
		this.panningEnvelopeValues = new Array<Int>();
		
		for (i in 0 ... XMInstrument.ENVELOPE_MAXIMUM_POINTS)
		{
			this.volumeEnvelopeTicks[i] = i;
			this.volumeEnvelopeValues[i] = 0;
			this.panningEnvelopeTicks[i] = i;
			this.panningEnvelopeValues[i] = 0;			
		}
		
		this.vibratoType = 0;
		this.vibratoSweep = 0;
		this.vibratoDepth = 0;
		this.vibratoRate = 0;
		
		this.fadeout = XMInstrument.FADEOUT_MAX;
	}
	
}