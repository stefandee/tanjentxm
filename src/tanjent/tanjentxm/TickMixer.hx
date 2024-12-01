/* Licensed under The MIT License (MIT), see license.txt*/
package tanjent.tanjentxm;

/** <p>
 * Renders a current {@link XMModule} state to the buffers leftSamples and rightSamples.
 * </p>
 * @author Jonas Murman */
class TickMixer
{
		
	/// Don't change this while playing. Create a new TickMixer instead.
	private var sampleRate:Int;
	
	/// Rendered left samples in FP-format
	public var leftSamples:Array<Int>;
	/// Rendered right samples in FP-format
	public var rightSamples:Array<Int>;
		
	/**
	 * Creates a new TickMixer and allocates the sample render buffers.  
	 * @param sampleRate the sample rate to use when mixing (usually 44100 samples/second)
	 */	
	public function new(sampleRate:Int)
	{
		if (sampleRate <= 0) sampleRate = 44100;
		this.sampleRate = sampleRate;

		// create render buffers
		var size:Int = this.getMaxTickSampleBufferSize();
		this.leftSamples = new Array<Int>();
		this.rightSamples = new Array<Int>();
		for (i in 0 ... size)
		{
			this.leftSamples[i] = 0;
			this.rightSamples[i] = 0;
		}		
	}
	
	/**
	 * Calculates the maximum render buffer size for one module tick
	 * @return the maximum render buffer size for one module tick
	 */
	public function getMaxTickSampleBufferSize():Int
	{
		return Std.int(XMModule.TICK_TO_SECONDS / XMModule.LOWEST_BPM * this.sampleRate);
	}

	/**
	 * Renders a tick with nearest neighbor interpolation. This will alias badly, but it is very fast.
	 * Use this for 2-32 channel modules on mobile and similar slower CPU-devices. 
	 * @param module the module with the current tick state to render 
	 * @return the number of samples rendered
	 */
	public function renderTickNoInterpolation(module:XMModule):Int
	{
		var channelsRendered:Int = 0;
		var mixFactorFP:Int = module.mixFactorFP;
		var sampleDataFP:Int;
		var sampleDataLeftFP:Int;
		var sampleDataRightFP:Int;
		var sampleDataPositionI:Int;

		// pitch interpolation
		var samplePositionAdd:Float;
		var samplePositionAddDelta:Float;

		// volume fx interpolation
		var volFactorFP:Int;
		var volFactorAddFP:Int;

		// panning envelope interpolation
		var panLeftFP:Int;
		var panRightFP:Int;
		var panLeftAddFP:Int;
		var panRightAddFP:Int;		
		
		var channel:XMChannel;
		var sample:XMSample;
		
		// global volume
		var globalVolumeFP:Int = module.globalVolumeFP;
		
		for (c in 0 ... module.numberOfChannels)
		{
			if (module.channels[c].playing == false) continue;
						
			channel = module.channels[c];
			sample = channel.sample;
			var i:Int = 0;
			
			volFactorFP = FixedPoint.FLOAT_TO_FP(channel.volumeFactorTickStart);
			volFactorAddFP = FixedPoint.FLOAT_TO_FP((channel.volumeFactorTickEnd - channel.volumeFactorTickStart) / (module.tickSamplesToRender - 1));

			samplePositionAdd = channel.samplePositionAddTickStart;
			samplePositionAddDelta = (channel.samplePositionAddTickEnd - channel.samplePositionAddTickStart) / (module.tickSamplesToRender - 1);
						
			// is channel silent?
			if (channel.volumeFP == 0 && volFactorAddFP == 0)
			{
				// channel must be silent during the entire tick, just update the sample position			
				channel.samplePosition += samplePositionAdd * module.tickSamplesToRender;
				if (channel.samplePosition >= sample.sampleLoopEndPosition)
				{
					channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
					if (channel.samplePosition < XMSample.SAMPLE_START)
					{
						// reached end of sample, no more data to play
						channel.playing = false;
					}
				}
				// go to next channel
				continue;
			}
			
			panLeftFP = FixedPoint.FLOAT_TO_FP(channel.panningEnvelopeLeftValueTickStart);
			panRightFP = FixedPoint.FLOAT_TO_FP(channel.panningEnvelopeRightValueTickStart);
			panLeftAddFP = FixedPoint.FLOAT_TO_FP((channel.panningEnvelopeLeftValueTickEnd - channel.panningEnvelopeLeftValueTickStart) / (module.tickSamplesToRender - 1));
			panRightAddFP = FixedPoint.FLOAT_TO_FP((channel.panningEnvelopeRightValueTickEnd - channel.panningEnvelopeRightValueTickStart) / (module.tickSamplesToRender - 1));
			
			// mix channel WITHOUT panning envelope?
			if (panLeftFP == 0 && panRightFP == 0 && panLeftAddFP == 0 && panRightAddFP == 0)
			{
				if (channelsRendered == 0)
				{
					// REPLACE leftSamples and rightSamples with new samples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
										
									
								// fill what's left in the buffer with zeroes
								while (i < module.tickSamplesToRender)
								{
									this.leftSamples[i] = 0;
									this.rightSamples[i] = 0;
									i++;
								}
								break;
							}
						}

						// get sample data, no interpolation
						sampleDataFP = sample.dataFP[Std.int(channel.samplePosition)];

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;
						
						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * channel.panningLeftFP) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * channel.panningRightFP) >> FixedPoint.FP_SHIFT;

						// replace with sample data
						this.leftSamples[i] = (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] = (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
					}
				} else {
					// ADD samples to leftSamples and rightSamples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
								break;
							}
						}

						// get sample data, no interpolation
						sampleDataFP = sample.dataFP[Std.int(channel.samplePosition)];

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;
						
						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * channel.panningLeftFP) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * channel.panningRightFP) >> FixedPoint.FP_SHIFT;

						// add sample data
						this.leftSamples[i] += (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] += (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
					}
				}				
			} else {
				// mix channel WITH panning envelope
				if (channelsRendered == 0)
				{
					// REPLACE leftSamples and rightSamples with new samples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;

								// fill what's left in the buffer with zeroes
								while (i < module.tickSamplesToRender)
								{
									this.leftSamples[i] = 0;
									this.rightSamples[i] = 0;
									i++;
								}
								break;
							}
						}

						// get sample data, no interpolation
						sampleDataFP = sample.dataFP[Std.int(channel.samplePosition)];

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;

						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * (channel.panningLeftFP + panLeftFP)) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * (channel.panningRightFP + panRightFP)) >> FixedPoint.FP_SHIFT;

						// replace with sample data
						this.leftSamples[i] = (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] = (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
						panLeftFP += panLeftAddFP;
						panRightFP += panRightAddFP;						
					}
				} else {
					// ADD samples to leftSamples and rightSamples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
								break;
							}
						}

						// get sample data, no interpolation
						sampleDataFP = sample.dataFP[Std.int(channel.samplePosition)];

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;

						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * (channel.panningLeftFP + panLeftFP)) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * (channel.panningRightFP + panRightFP)) >> FixedPoint.FP_SHIFT;

						// add sample data
						this.leftSamples[i] += (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] += (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
						panLeftFP += panLeftAddFP;
						panRightFP += panRightAddFP;
					}
				}
			}
			
			channelsRendered++;
 		}
		
		if (channelsRendered == 0)
		{
			// zero buffer in case of totally silent tick
			for (i in 0 ... module.tickSamplesToRender)
			{
				this.leftSamples[i] = 0;
				this.rightSamples[i] = 0;				
			}			
		} else if (globalVolumeFP != FixedPoint.FP_ONE) {
			// handle global volume
			for (i in 0 ... module.tickSamplesToRender)
			{
				this.leftSamples[i] = (this.leftSamples[i] * globalVolumeFP) >> FixedPoint.FP_SHIFT;
				this.rightSamples[i] = (this.rightSamples[i] * globalVolumeFP) >> FixedPoint.FP_SHIFT;				
			}
		}
			
		return module.tickSamplesToRender;
	}
	
	/**
	 * Renders a tick with linear interpolation. This will alias less badly and is a good overall choice.
	 * Use this for 2-16 channel modules on mobile and similar slower CPU-devices.
	 * @param module the module with the current tick state to render 
	 * @return the number of samples rendered
	 */
	public function renderTickLinearInterpolation(module:XMModule):Int
	{
		
		var channelsRendered:Int = 0;
		var mixFactorFP:Int = module.mixFactorFP;
		var sampleDataFP:Int;
		var sampleDataLeftFP:Int;
		var sampleDataRightFP:Int;
		var sampleDataPositionI:Int;

		// linear interpolation
		var cy1:Int;
		var cy2:Int;
		var cx:Int;
		
		// pitch interpolation
		var samplePositionAdd:Float;
		var samplePositionAddDelta:Float;

		// volume fx interpolation
		var volFactorFP:Int;
		var volFactorAddFP:Int;

		// panning envelope interpolation
		var panLeftFP:Int;
		var panRightFP:Int;
		var panLeftAddFP:Int;
		var panRightAddFP:Int;		
		
		var channel:XMChannel;
		var sample:XMSample;

		// global volume
		var globalVolumeFP:Int = module.globalVolumeFP;

		for (c in 0 ... module.numberOfChannels)
		{
			if (module.channels[c].playing == false) continue;
			
			channel = module.channels[c];
			sample = channel.sample;
			var i:Int = 0;
			
			volFactorFP = FixedPoint.FLOAT_TO_FP(channel.volumeFactorTickStart);
			volFactorAddFP = FixedPoint.FLOAT_TO_FP((channel.volumeFactorTickEnd - channel.volumeFactorTickStart) / (module.tickSamplesToRender - 1));

			samplePositionAdd = channel.samplePositionAddTickStart;
			samplePositionAddDelta = (channel.samplePositionAddTickEnd - channel.samplePositionAddTickStart) / (module.tickSamplesToRender - 1);
						
			// is channel silent?
			if (channel.volumeFP == 0 && volFactorAddFP == 0)
			{
				// channel must be silent during the entire tick, just update the sample position			
				channel.samplePosition += samplePositionAdd * module.tickSamplesToRender;
				if (channel.samplePosition >= sample.sampleLoopEndPosition)
				{
					channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
					if (channel.samplePosition < XMSample.SAMPLE_START)
					{
						// reached end of sample, no more data to play
						channel.playing = false;
					}
				}
				// go to next channel
				continue;
			}
			
			panLeftFP = FixedPoint.FLOAT_TO_FP(channel.panningEnvelopeLeftValueTickStart);
			panRightFP = FixedPoint.FLOAT_TO_FP(channel.panningEnvelopeRightValueTickStart);
			panLeftAddFP = FixedPoint.FLOAT_TO_FP((channel.panningEnvelopeLeftValueTickEnd - channel.panningEnvelopeLeftValueTickStart) / (module.tickSamplesToRender - 1));
			panRightAddFP = FixedPoint.FLOAT_TO_FP((channel.panningEnvelopeRightValueTickEnd - channel.panningEnvelopeRightValueTickStart) / (module.tickSamplesToRender - 1));
			
			// mix channel WITHOUT panning envelope?
			if (panLeftFP == 0 && panRightFP == 0 && panLeftAddFP == 0 && panRightAddFP == 0)
			{
				if (channelsRendered == 0)
				{
					// REPLACE leftSamples and rightSamples with new samples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
													
								// fill what's left in the buffer with zeroes
								while (i < module.tickSamplesToRender)
								{
									this.leftSamples[i] = 0;
									this.rightSamples[i] = 0;
									i++;
								}
								break;
							}
						}

						// get sample data and linear interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);
                        cy1 = sample.dataFP[sampleDataPositionI];
                        cy2 = sample.dataFP[sampleDataPositionI + 1];
                        cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
                        sampleDataFP = ((cy1 * (FixedPoint.FP_ONE - cx)) >> FixedPoint.FP_SHIFT) + ((cy2 * cx) >> FixedPoint.FP_SHIFT);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;
						
						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * channel.panningLeftFP) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * channel.panningRightFP) >> FixedPoint.FP_SHIFT;

						// replace with sample data
						this.leftSamples[i] = (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] = (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
					}
				} else {
					// ADD samples to leftSamples and rightSamples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
								break;
							}
						}

						// get sample data and linear interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);
                        cy1 = sample.dataFP[sampleDataPositionI];
                        cy2 = sample.dataFP[sampleDataPositionI + 1];
                        cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
                        sampleDataFP = ((cy1 * (FixedPoint.FP_ONE - cx)) >> FixedPoint.FP_SHIFT) + ((cy2 * cx) >> FixedPoint.FP_SHIFT);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;
						
						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * channel.panningLeftFP) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * channel.panningRightFP) >> FixedPoint.FP_SHIFT;

						// add sample data
						this.leftSamples[i] += (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] += (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
					}
				}				
			} else {
				// mix channel WITH panning envelope
				if (channelsRendered == 0)
				{
					// REPLACE leftSamples and rightSamples with new samples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;

								// fill what's left in the buffer with zeroes
								while (i < module.tickSamplesToRender)
								{
									this.leftSamples[i] = 0;
									this.rightSamples[i] = 0;
									i++;
								}
								break;
							}
						}
						
						// get sample data and linear interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);
                        cy1 = sample.dataFP[sampleDataPositionI];
                        cy2 = sample.dataFP[sampleDataPositionI + 1];
                        cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
                        sampleDataFP = ((cy1 * (FixedPoint.FP_ONE - cx)) >> FixedPoint.FP_SHIFT) + ((cy2 * cx) >> FixedPoint.FP_SHIFT);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;

						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * (channel.panningLeftFP + panLeftFP)) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * (channel.panningRightFP + panRightFP)) >> FixedPoint.FP_SHIFT;

						// replace with sample data
						this.leftSamples[i] = (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] = (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
						panLeftFP += panLeftAddFP;
						panRightFP += panRightAddFP;						
					}
				} else {
					// ADD samples to leftSamples and rightSamples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
								break;
							}
						}

						// get sample data and linear interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);
                        cy1 = sample.dataFP[sampleDataPositionI];
                        cy2 = sample.dataFP[sampleDataPositionI + 1];
                        cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
                        sampleDataFP = ((cy1 * (FixedPoint.FP_ONE - cx)) >> FixedPoint.FP_SHIFT) + ((cy2 * cx) >> FixedPoint.FP_SHIFT);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;

						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * (channel.panningLeftFP + panLeftFP)) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * (channel.panningRightFP + panRightFP)) >> FixedPoint.FP_SHIFT;

						// add sample data
						this.leftSamples[i] += (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] += (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
						panLeftFP += panLeftAddFP;
						panRightFP += panRightAddFP;
					}
				}
			}
			
			channelsRendered++;
 		}
		
		if (channelsRendered == 0)
		{
			// zero buffer in case of totally silent tick
			for (i in 0 ... module.tickSamplesToRender)
			{
				this.leftSamples[i] = 0;
				this.rightSamples[i] = 0;				
			}			
		} else if (globalVolumeFP != FixedPoint.FP_ONE) {
			// handle global volume
			for (i in 0 ... module.tickSamplesToRender)
			{
				this.leftSamples[i] = (this.leftSamples[i] * globalVolumeFP) >> FixedPoint.FP_SHIFT;
				this.rightSamples[i] = (this.rightSamples[i] * globalVolumeFP) >> FixedPoint.FP_SHIFT;				
			}
		}
		
		return module.tickSamplesToRender;
	}	


	/**
	 * Renders a tick with cubic polynomial interpolation. Very little aliasing.
	 * Use this for 2-8 channel modules on mobile and similar slower CPU-devices.
	 * @param module the module with the current tick state to render 
	 * @return the number of samples rendered
	 */
	public function renderTickCubicInterpolation(module:XMModule):Int
	{
		
		var channelsRendered:Int = 0;
		var mixFactorFP:Int = module.mixFactorFP;
		var sampleDataFP:Int;
		var sampleDataLeftFP:Int;
		var sampleDataRightFP:Int;
		var sampleDataPositionI:Int;

		// cubic interpolation
		var cy0:Int;
		var cy1:Int;
		var cy2:Int;
		var cy3:Int;
		var cc:Int;
		var cv:Int;
		var cw:Int;
		var ca:Int;
		var cb:Int;
		var cx:Int;
		
		// pitch interpolation
		var samplePositionAdd:Float;
		var samplePositionAddDelta:Float;

		// volume fx interpolation
		var volFactorFP:Int;
		var volFactorAddFP:Int;

		// panning envelope interpolation
		var panLeftFP:Int;
		var panRightFP:Int;
		var panLeftAddFP:Int;
		var panRightAddFP:Int;		
		
		var channel:XMChannel;
		var sample:XMSample;

		// global volume
		var globalVolumeFP:Int = module.globalVolumeFP;

		for (c in 0 ... module.numberOfChannels)
		{
			if (module.channels[c].playing == false) continue;
			
			channel = module.channels[c];
			sample = channel.sample;
			var i:Int = 0;
			
			volFactorFP = FixedPoint.FLOAT_TO_FP(channel.volumeFactorTickStart);
			volFactorAddFP = FixedPoint.FLOAT_TO_FP((channel.volumeFactorTickEnd - channel.volumeFactorTickStart) / (module.tickSamplesToRender - 1));

			samplePositionAdd = channel.samplePositionAddTickStart;
			samplePositionAddDelta = (channel.samplePositionAddTickEnd - channel.samplePositionAddTickStart) / (module.tickSamplesToRender - 1);
						
			// is channel silent?
			if (channel.volumeFP == 0 && volFactorAddFP == 0)
			{
				// channel must be silent during the entire tick, just update the sample position			
				channel.samplePosition += samplePositionAdd * module.tickSamplesToRender;
				if (channel.samplePosition >= sample.sampleLoopEndPosition)
				{
					channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
					if (channel.samplePosition < XMSample.SAMPLE_START)
					{
						// reached end of sample, no more data to play
						channel.playing = false;
					}
				}
				// go to next channel
				continue;
			}
			
			panLeftFP = FixedPoint.FLOAT_TO_FP(channel.panningEnvelopeLeftValueTickStart);
			panRightFP = FixedPoint.FLOAT_TO_FP(channel.panningEnvelopeRightValueTickStart);
			panLeftAddFP = FixedPoint.FLOAT_TO_FP((channel.panningEnvelopeLeftValueTickEnd - channel.panningEnvelopeLeftValueTickStart) / (module.tickSamplesToRender - 1));
			panRightAddFP = FixedPoint.FLOAT_TO_FP((channel.panningEnvelopeRightValueTickEnd - channel.panningEnvelopeRightValueTickStart) / (module.tickSamplesToRender - 1));
			
			// mix channel WITHOUT panning envelope?
			if (panLeftFP == 0 && panRightFP == 0 && panLeftAddFP == 0 && panRightAddFP == 0)
			{
				if (channelsRendered == 0)
				{
					// REPLACE leftSamples and rightSamples with new samples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
													
								// fill what's left in the buffer with zeroes
								while (i < module.tickSamplesToRender)
								{
									this.leftSamples[i] = 0;
									this.rightSamples[i] = 0;
									i++;
								}
								break;
							}
						}

						// get sample data and interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);

						// cubic interpolation
						cy0 = sample.dataFP[sampleDataPositionI - 1];
						cy1 = sample.dataFP[sampleDataPositionI];
						cy2 = sample.dataFP[sampleDataPositionI + 1];
						cy3 = sample.dataFP[sampleDataPositionI + 2];
						cc = (cy2 - cy0) >> 1;
						cv = cy1 - cy2;
						cw = cc + cv;
						ca = cw + cv + ((cy3 - cy1) >> 1);
						cb = cw + ca;
						cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
						sampleDataFP = (((((((((ca * cx) >> FixedPoint.FP_SHIFT) - cb) * cx) >> FixedPoint.FP_SHIFT) + cc) * cx) >> FixedPoint.FP_SHIFT) + cy1);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;
						
						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * channel.panningLeftFP) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * channel.panningRightFP) >> FixedPoint.FP_SHIFT;

						// replace with sample data
						this.leftSamples[i] = (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] = (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
					}
				} else {
					// ADD samples to leftSamples and rightSamples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
								break;
							}
						}

						// get sample data and interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);

						// cubic interpolation
						cy0 = sample.dataFP[sampleDataPositionI - 1];
						cy1 = sample.dataFP[sampleDataPositionI];
						cy2 = sample.dataFP[sampleDataPositionI + 1];
						cy3 = sample.dataFP[sampleDataPositionI + 2];
						cc = (cy2 - cy0) >> 1;
						cv = cy1 - cy2;
						cw = cc + cv;
						ca = cw + cv + ((cy3 - cy1) >> 1);
						cb = cw + ca;
						cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
						sampleDataFP = (((((((((ca * cx) >> FixedPoint.FP_SHIFT) - cb) * cx) >> FixedPoint.FP_SHIFT) + cc) * cx) >> FixedPoint.FP_SHIFT) + cy1);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;
						
						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * channel.panningLeftFP) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * channel.panningRightFP) >> FixedPoint.FP_SHIFT;

						// add sample data
						this.leftSamples[i] += (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] += (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
					}
				}				
			} else {
				// mix channel WITH panning envelope
				if (channelsRendered == 0)
				{
					// REPLACE leftSamples and rightSamples with new samples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;

								// fill what's left in the buffer with zeroes
								while (i < module.tickSamplesToRender)
								{
									this.leftSamples[i] = 0;
									this.rightSamples[i] = 0;
									i++;
								}
								break;
							}
						}

						// get sample data and interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);

						// cubic interpolation
						cy0 = sample.dataFP[sampleDataPositionI - 1];
						cy1 = sample.dataFP[sampleDataPositionI];
						cy2 = sample.dataFP[sampleDataPositionI + 1];
						cy3 = sample.dataFP[sampleDataPositionI + 2];
						cc = (cy2 - cy0) >> 1;
						cv = cy1 - cy2;
						cw = cc + cv;
						ca = cw + cv + ((cy3 - cy1) >> 1);
						cb = cw + ca;
						cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
						sampleDataFP = (((((((((ca * cx) >> FixedPoint.FP_SHIFT) - cb) * cx) >> FixedPoint.FP_SHIFT) + cc) * cx) >> FixedPoint.FP_SHIFT) + cy1);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;

						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * (channel.panningLeftFP + panLeftFP)) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * (channel.panningRightFP + panRightFP)) >> FixedPoint.FP_SHIFT;

						// replace with sample data
						this.leftSamples[i] = (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] = (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
						panLeftFP += panLeftAddFP;
						panRightFP += panRightAddFP;						
					}
				} else {
					// ADD samples to leftSamples and rightSamples
					while (i < module.tickSamplesToRender)
					{
						// update sample pointer						
						if (channel.samplePosition >= sample.sampleLoopEndPosition)
						{
							channel.samplePosition = sample.getWrappedSamplePosition(channel.samplePosition);
							if (channel.samplePosition < XMSample.SAMPLE_START)
							{
								// reached end of sample, no more data to play
								channel.playing = false;
								break;
							}
						}

						// get sample data and interpolate
						sampleDataPositionI = Std.int(channel.samplePosition);

						// cubic interpolation
						cy0 = sample.dataFP[sampleDataPositionI - 1];
						cy1 = sample.dataFP[sampleDataPositionI];
						cy2 = sample.dataFP[sampleDataPositionI + 1];
						cy3 = sample.dataFP[sampleDataPositionI + 2];
						cc = (cy2 - cy0) >> 1;
						cv = cy1 - cy2;
						cw = cc + cv;
						ca = cw + cv + ((cy3 - cy1) >> 1);
						cb = cw + ca;
						cx = FixedPoint.FLOAT_TO_FP(channel.samplePosition - sampleDataPositionI); // frac of channel.samplePosition
						sampleDataFP = (((((((((ca * cx) >> FixedPoint.FP_SHIFT) - cb) * cx) >> FixedPoint.FP_SHIFT) + cc) * cx) >> FixedPoint.FP_SHIFT) + cy1);

						// adjust for channel volume and volume delta effects (tremolo, envelope)
						sampleDataFP = (sampleDataFP * ((channel.volumeFP_LPF * volFactorFP) >> FixedPoint.FP_SHIFT)) >> FixedPoint.FP_SHIFT;

						// adjust for channel panning
						sampleDataLeftFP = (sampleDataFP * (channel.panningLeftFP + panLeftFP)) >> FixedPoint.FP_SHIFT;
						sampleDataRightFP = (sampleDataFP * (channel.panningRightFP + panRightFP)) >> FixedPoint.FP_SHIFT;

						// add sample data
						this.leftSamples[i] += (sampleDataLeftFP * mixFactorFP) >> FixedPoint.FP_SHIFT;
						this.rightSamples[i] += (sampleDataRightFP * mixFactorFP) >> FixedPoint.FP_SHIFT;

						// update
						channel.samplePosition += samplePositionAdd;

						// LPF volumeFP to prevent zipper noise
						channel.volumeFP_LPF = ((channel.volumeFP * FixedPoint.FP_ZERO_POINT_05) >> FixedPoint.FP_SHIFT) + ((channel.volumeFP_LPF * FixedPoint.FP_ZERO_POINT_95) >> FixedPoint.FP_SHIFT);

						i++;
						samplePositionAdd += samplePositionAddDelta;
						volFactorFP += volFactorAddFP;
						panLeftFP += panLeftAddFP;
						panRightFP += panRightAddFP;
					}
				}
			}
			
			channelsRendered++;
 		}
		
		if (channelsRendered == 0)
		{
			// zero buffer in case of totally silent tick
			for (i in 0 ... module.tickSamplesToRender)
			{
				this.leftSamples[i] = 0;
				this.rightSamples[i] = 0;				
			}			
		} else if (globalVolumeFP != FixedPoint.FP_ONE) {
			// handle global volume
			for (i in 0 ... module.tickSamplesToRender)
			{
				this.leftSamples[i] = (this.leftSamples[i] * globalVolumeFP) >> FixedPoint.FP_SHIFT;
				this.rightSamples[i] = (this.rightSamples[i] * globalVolumeFP) >> FixedPoint.FP_SHIFT;				
			}
		}
		
		return module.tickSamplesToRender;
	}
	
	
}