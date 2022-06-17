# Solution 1

## Data Flow
CloudWatch Logs -> Subscription Filter -> Lambda Transform -> Opensearch domain

This solution is available on th AWS console as Terraform does not yet support an Opensearch target from the subscription filter resource