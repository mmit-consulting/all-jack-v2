# S3 Access Control: The 3 Layers

## Layer 1: Bucket Policy / IAM Policy (Recommended)

- These are **JSON policies** that define what actions (like `s3:GetObject`, `s3:PutObject`) are allowed for **principals** (IAM users, roles, accounts).
- Applied at **account level**, not object level.
- Centralized, auditable, and scalable.

**Preferred by AWS and security teams.**

## Layer 2: ACLs (Access Control Lists) [Legacy]

- **Each object and bucket** has an ACL (a list of permissions granted to AWS accounts or groups).
- You can grant object-level access (e.g., allow another account to read an object).
- **This can enable public access if used improperly**.

**Hard to audit and control at scale.**

## Layer 3: Block Public Access Settings

- A security feature that **overrides ACLs or bucket policies to block public access**.
- You can enable this to:
  - Block public access through ACLs
  - Block public access through bucket policies

**Should be ON in almost all cases unless you truly need public files.**

# Object Ownership in ACL-Enabled Buckets - Deep Dive

When **ACLs are enabled**, you can **choose how S3 determines the owner of newly uploaded objects**.

## Option 1: Object Writer (default legacy behavior)

- Whoever uploads the object becomes the **owner**.
- Even if they upload to your bucket, you (the bucket owner) may **not have access**.

Common issue: “I can’t delete or read files in my own bucket!”

## Option 2: Bucket Owner Preferred

- If the uploader includes ACL `bucket-owner-full-control`, you (bucket owner) become the owner.
- But if they forget that ACL, the uploader still owns the object.

# Disabling ACLs (ObjectOwnership = BucketOwnerEnforced)

When you disable ACLs:

- **Object-level ACLs are ignored**
- **All new objects are automatically owned by the bucket owner**
- Uploads using ACLs are **rejected**
- Access control is enforced **only through policies** (IAM / bucket)

This is clean, predictable, and solves the ownership conflict.

## full impact on existing objects:

| Aspect                   | What happens after disabeling ACLs                                                           |
| ------------------------ | -------------------------------------------------------------------------------------------- |
| Object ACLs              | ❌ Still exist but ignored — not used for access control anymore                             |
| Object ownership         | ✅ Remains unchanged — uploader still owns the object                                        |
| Bucket owner access      | ❌ May still not have access, unless granted via bucket/IAM policy                           |
| Object-level permissions | ❌ ACL-based permissions are no longer enforced (object-level policies only via S3 policies) |
| New ACLs                 | ❌ Cannot be set or updated — results in AccessControlListNotSupported error                 |
| Access control method    | ✅ Must use bucket policy (cross-account) or IAM policy (same-account) to manage access      |

ACLs are ignored entirely — even if the object was uploaded before.

Ownership is not forcibly transferred — but only policies matter now.

Bucket owner must use policies to gain access to objects they don't own.

---

# Summary

- S3 ignores the ACLs on existing objects when the bucket has: ObjectOwnership = BucketOwnerEnforced
- Even if an object was originally created when the bucket had ObjectOwnership = ObjectWriter, and the uploader (not the bucket owner) owned the object.
- As soon as you change the bucket to BucketOwnerEnforced, S3

- Ignores the ACLs on that object
- The object still belongs to the uploader (ownership does not change)
- The ACL is still attached, but
- S3 ignores it for all access control decisions

## So What Does That Mean in Practice?

Let’s say:

1. An object was uploaded by `test-user` while the bucket was in **ObjectWriter** mode.

- The object is owned by `test-user`.
- The ACL might give (bucket owner) no access.

2. You later change the bucket to: ObjectOwnership = BucketOwnerEnforced (disabled ACL)

Now

- BUCKET OWNER tries to GetObject, DeleteObject, etc.
- The object's ACL still exists (you can get-object-acl and see it).
- ❌ But S3 ignores that ACL.
- ✅ S3 checks only IAM or bucket policies to decide if Mahdi can access it.

### This Is the Key Insight:

- Ownership remains unchanged.
- But S3 ACL enforcement is globally turned off.

So even though test-user is still the "owner" of the object:

- Their ACL no longer controls access.
- The bucket owner's IAM/bucket policies can override it.

==> Docs: https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html

### AWS Doc Excerpt: Controlling Ownership & Disabling ACLs

- In the case of an existing bucket that already has objects in it, after you disable ACLs, the object and bucket ACLs are no longer part of an access evaluation, and access is granted or denied on the basis of policies.

- After the Bucket owner enforced setting is applied:
  - All bucket ACLs and object ACLs are disabled, which gives full access to you, as the bucket owner.
  - ACLs no longer affect access permissions to your bucket. As a result, access control for your data is based on policies, such as IAM identity-based policies, S3 bucket policies
- All objects that were already in your bucket before you disabled ACLs remain unchanged, but their ACLs are no longer used by Amazon S3 to control access.

#### What This Means

- Existing ACLs (public-read or custom grants) ==> ❌ They still exist in metadata but are not used in access control
- Existing object ownership ==> ✅ Ownership remains unchanged
- Access decisions ==> ✅ Made exclusively through IAM/bucket policies
- ACL-based access grants ==> ❌ No longer applied — ignored by S3
