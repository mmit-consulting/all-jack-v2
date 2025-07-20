# S3 Object Ownership & ACL Demo (Internal vs Master Account)

## Objective

Demonstrate how ACLs and Object Ownership modes impact access and ownership of S3 objects across **two AWS accounts**:

- internal-account (bucket owner)
- master-account (external uploader)

## 1. Create a bucket with Object Ownership = ObjectWriter

```bash
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --profile $INTERNAL_PROFILE

# Set ObjectOwnership = ObjectWriter
aws s3api put-bucket-ownership-controls \
  --bucket $BUCKET_NAME \
  --ownership-controls 'Rules=[{ObjectOwnership=ObjectWriter}]' \
  --profile $INTERNAL_PROFILE
```

## 2. Upload object1 from internal account

```bash
echo "internal-object" > internal.txt
aws s3 cp internal.txt s3://$BUCKET_NAME/internal-object.txt --profile $INTERNAL_PROFILE
```

## 3. Allow master account to write (cross-account)

```bash
cat <<EOF > bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowMasterUpload",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<MASTER_ACCOUNT_ID>:root"
      },
      "Action": ["s3:PutObject", "s3:PutObjectAcl"],
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file://bucket-policy.json \
  --profile $INTERNAL_PROFILE
```

## 4. Upload 2 objects from master account (ACL vs No ACL)

```bash
echo "master-no-acl" > master-no-acl.txt
echo "master-acl" > master-acl.txt

# Without ACL
aws s3 cp master-no-acl.txt s3://$BUCKET_NAME/master-no-acl.txt \
  --profile $MASTER_PROFILE

# With ACL (bucket-owner-full-control)
aws s3 cp master-acl.txt s3://$BUCKET_NAME/master-acl.txt \
  --acl bucket-owner-full-control \
  --profile $MASTER_PROFILE
```

## 5. Change ownership mode to BucketOwnerPreferred

```bash
aws s3api put-bucket-ownership-controls \
  --bucket $BUCKET_NAME \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerPreferred}]' \
  --profile $INTERNAL_PROFILE
```

## 6. Upload 2 more objects from master account

```bash
echo "master-preferred-no-acl" > preferred-no-acl.txt
echo "master-preferred-acl" > preferred-acl.txt

# Without ACL
aws s3 cp preferred-no-acl.txt s3://$BUCKET_NAME/preferred-no-acl.txt \
  --profile $MASTER_PROFILE

# With ACL (bucket-owner-full-control)
aws s3 cp preferred-acl.txt s3://$BUCKET_NAME/preferred-acl.txt \
  --acl bucket-owner-full-control \
  --profile $MASTER_PROFILE
```

## 7. Inspect ownership in AWS Console (internal account)

- Go to S3 console → Bucket → Objects
- For each object:
  - Click on it
  - Look at Object Owner (Internal or Master)
  - Try downloading(deleting) it from Internal account

We should now have:

| Object               | Uploaded By | ACL?                   | Ownership Metadata   | Effective Access (Internal)  |
| -------------------- | ----------- | ---------------------- | -------------------- | ---------------------------- |
| internal-object.txt  | Internal    | N/A                    | Internal             | ✅ Yes                       |
| master-no-acl.txt    | Master      | ❌ No ACL              | Master               | ❌ No (unless policy allows) |
| master-acl.txt       | Master      | ✅ `bucket-owner-full` | Master               | ✅ Yes                       |
| preferred-no-acl.txt | Master      | ❌ No ACL              | Internal (preferred) | ❌ No (unless policy allows) |
| preferred-acl.txt    | Master      | ✅ `bucket-owner-full` | Internal (preferred) | ✅ Yes                       |

Note: After ACLs are disabled, ACLs are ignored — ownership metadata remains, but access is policy-driven only.

## 8. Switch to BucketOwnerEnforced (ACLs disabled)

```bash
aws s3api put-bucket-ownership-controls \
  --bucket $BUCKET_NAME \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]' \
  --profile $INTERNAL_PROFILE
```

This disables all ACLs. From now on:

- All new objects are automatically owned by the bucket owner (Internal).
- Existing object ACLs are ignored for access decisions (but still visible).
- Access is fully controlled by policies only (bucket/IAM)

## 9. Inspect Again (ACL disabled)

| Object               | Uploaded By | ACL (ignored)                    | Ownership Metadata | Effective Access (Internal)  |
| -------------------- | ----------- | -------------------------------- | ------------------ | ---------------------------- |
| internal-object.txt  | Internal    | N/A                              | Internal           | ✅ Yes                       |
| master-no-acl.txt    | Master      | ❌ No ACL                        | Internal           | ✅ No (unless policy allows) |
| master-acl.txt       | Master      | ✅ `bucket-owner-full` (ignored) | Internal           | ✅ No (unless policy allows) |
| preferred-no-acl.txt | Master      | ❌ No ACL                        | Internal           | ✅ Yes (owned by internal)   |
| preferred            | Master      | ✅ `bucket-owner-full` (ignored) | Internal           | ✅ Yes (owned by internal)   |

Even though some objects had ACLs, they're now ignored. Internal access is governed exclusively by bucket/IAM policy.

## 10. Conclusion

- ACLs disabled = access fully controlled by policies.
- Ownership metadata doesn't change, but ACLs no longer grant access.
- If you still need access to objects owned by other accounts, use:
  - Bucket policy (for cross-account access)
  - IAM policy (for same-account access)
  - Or copy/re-upload objects to transfer ownership.
