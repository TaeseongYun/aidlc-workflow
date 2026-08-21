# NFR Checklist

After the functional requirements are organized, the following items must be checked.

## Performance
- Is there a response time target
- Is bulk/batch processing required

## Consistency
- Is duplicate-processing prevention required
- Is state-transition atomicity required

## Security
- Is authorization verification required
- Is personal information/payment information included

## Operations
- Are notifications/failure retries/audit logs required
- Is a scheduled job or scheduler required

## Testing
- Unit tests
- Integration tests
- Exception scenario tests

## Scalability
- Is there a high likelihood of future policy changes
- Could the cost-bearing party/channel/type grow
