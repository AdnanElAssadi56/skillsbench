Get the population differentiated common variants from each slice in /root/data/. For each, restrict to biallelic SNVs in the slice's filter_sub_region (the manifest there has the per-slice details), keep MAF in [0.01, 0.99], and require |AFR_AF - EAS_AF| >= 0.10.

Filtered VCFs (bgzipped + tabix-indexed) can be found at /root/output/<slice_id>/filtered.vcf.gz. Next to each filtered VCF, there is a summary.json file with slice_id, variant_count, variant_keys (sorted CHROM:POS:REF:ALT), and region.
