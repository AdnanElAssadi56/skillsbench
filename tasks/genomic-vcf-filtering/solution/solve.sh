#!/bin/bash
set -euo pipefail

# Oracle for genomic-vcf-filtering.
#
# Reads each slice from /root/data/slices.json and runs the same bcftools
# filter against it: restrict to the slice's filter_sub_region, keep biallelic
# SNVs, drop MAF<0.01 and MAF>0.99, then keep variants where AFR_AF and EAS_AF
# differ by at least 0.10. The "|x| >= T" condition is written as a disjunction
# because bcftools has no abs(). Output is one filtered VCF (bgzipped + tabix
# indexed) and one summary JSON per slice.

DATA=/root/data
OUT=/root/output
MANIFEST=$DATA/slices.json

mkdir -p "$OUT"

# Iterate over each slice from the manifest.
for SLICE_ID in $(python3 -c 'import json; print(" ".join(s["id"] for s in json.load(open("/root/data/slices.json"))["slices"]))'); do
    INPUT=$DATA/${SLICE_ID}.vcf.gz
    SUB_REGION=$(python3 -c "import json; m=json.load(open('/root/data/slices.json')); print([s['filter_sub_region'] for s in m['slices'] if s['id']=='$SLICE_ID'][0])")
    OUT_DIR=$OUT/${SLICE_ID}
    OUT_VCF=$OUT_DIR/filtered.vcf.gz
    OUT_SUMMARY=$OUT_DIR/summary.json

    mkdir -p "$OUT_DIR"

    bcftools view \
        --regions "$SUB_REGION" \
        --types snps \
        -m 2 -M 2 \
        -i 'INFO/AF >= 0.01 && INFO/AF <= 0.99 && (INFO/AFR_AF - INFO/EAS_AF >= 0.10 || INFO/EAS_AF - INFO/AFR_AF >= 0.10)' \
        -O z \
        -o "$OUT_VCF" \
        "$INPUT"

    tabix -p vcf -f "$OUT_VCF"

    python3 - "$SLICE_ID" "$OUT_VCF" "$SUB_REGION" "$OUT_SUMMARY" << 'PY'
import gzip, json, sys
slice_id, vcf, region, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
keys = []
with gzip.open(vcf, "rt") as f:
    for line in f:
        if line.startswith("#"):
            continue
        cols = line.rstrip("\n").split("\t")
        chrom, pos, _id, ref, alt = cols[0], cols[1], cols[2], cols[3], cols[4]
        keys.append(f"{chrom}:{pos}:{ref}:{alt}")
keys.sort()
summary = {
    "slice_id": slice_id,
    "variant_count": len(keys),
    "variant_keys": keys,
    "region": region,
}
with open(out, "w") as f:
    json.dump(summary, f, indent=2)
print(f"  {slice_id}: {len(keys)} variants kept")
PY
done

echo "Oracle complete — output at $OUT/"
