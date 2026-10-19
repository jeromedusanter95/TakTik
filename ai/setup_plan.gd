@abstract
class_name SetupPlan
extends Resource
## How a Bot arranges its Army before play starts.


@abstract func arrange(side: Side.Id, rng: RandomNumberGenerator) -> Setup
