'use strict'

/*
event -> {
  "AutoScalingGroupARN": "arn:aws:autoscaling:us-east-1:<account-id>:autoScalingGroup:d4738357-2d40-4038-ae7e-b00ae0227003:autoScalingGroupName/my-asg",
  "AutoScalingGroupName": "my-asg",
  "CapacityToTerminate": [
    {
      "AvailabilityZone": "us-east-1c",
      "Capacity": 3,
      "InstanceMarketOption": "OnDemand"
    }
  ],
  "Instances": [
    {
      "AvailabilityZone": "us-east-1c",
      "InstanceId": "i-02e1c69383a3ed501",
      "InstanceType": "t2.nano",
      "InstanceMarketOption": "OnDemand"
    },
    {
      "AvailabilityZone": "us-east-1c",
      "InstanceId": "i-036bc44b6092c01c7",
      "InstanceType": "t2.nano",
      "InstanceMarketOption": "OnDemand"
    },
    ...
  ],
  "Cause": "SCALE_IN"
}
 */

exports.handler = function(event, context, callback) {
  console.log('lambda input: ', JSON.stringify(event))
  const instanceIds = event.Instances.map(i => i.InstanceId)
  const response = {
    InstanceIDs: instanceIds
  }
  console.log('lambda output: ', response)
  callback(null, response)
}
