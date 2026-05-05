---
name: vcf-format-conventions
description: Reference for VCF v4.2 format conventions encountered in real population-genetics call sets — biallelic vs multi-allelic representation, the SNV vs indel vs MNP type distinction, the difference between Number=1, Number=A, Number=R, and Number=G INFO/FORMAT fields, normalization (left-alignment + decomposition) semantics, and the 1000 Genomes Project Phase 3 INFO-field schema. Use when filtering, normalizing, or transforming VCF data with bcftools.
---

# VCF v4.2 Format Conventions

The VCF specification is published by the Global Alliance for Genomics and Health (GA4GH) and maintained by HTSlib (<https://samtools.github.io/hts-specs/VCFv4.2.pdf>). Most population-genetics call sets — including the 1000 Genomes Project — conform to v4.2 with project-specific INFO-field extensions. This reference covers the conventions that affect filter and subset operations.

## Variant types

A single VCF record's "type" is determined by the relationship between the REF column and each ALT allele:

| Type | Definition | bcftools `--types` keyword |
|---|---|---|
| SNP / SNV | Single-base REF and single-base ALT, both A/C/G/T | `snps` |
| MNP | REF and ALT are equal-length multi-base sequences | `mnps` |
| Indel | REF and ALT differ in length (insertion or deletion) | `indels` |
| Symbolic / structural | ALT is a symbolic allele (`<DEL>`, `<DUP>`, …) | `other` |
| Reference | ALT is `.` (no variant called) | `ref` |

`bcftools view --types snps` keeps records where every ALT allele is a SNP; on a multi-allelic record with one SNP and one indel ALT, the entire record is excluded. Use `bcftools norm -m -` to split multi-allelics first if per-allele type filtering is needed.

## Biallelic vs multi-allelic

A biallelic record has exactly one ALT allele; a multi-allelic record has two or more, comma-separated in the ALT column. Many downstream tools assume biallelic input. The bcftools idiom for restricting to biallelic records is:

    bcftools view -m 2 -M 2 input.vcf.gz

`-m N` is the minimum number of alleles (REF + all ALTs) and `-M N` the maximum. `-m 2 -M 2` selects records with exactly REF + 1 ALT, i.e. biallelic. Combining with `--types snps` yields biallelic SNVs.

## INFO and FORMAT field cardinality

Every INFO and FORMAT field declares a `Number` in its header definition that controls how many values appear:

| Number | Meaning | Example |
|---|---|---|
| `1` | One value per record | `INFO/DP` (total depth) |
| `A` | One value per ALT allele | `INFO/AC` (allele count per ALT) |
| `R` | One value per REF + ALT | `INFO/AD` (FORMAT/AD allele depth) |
| `G` | One per genotype combination | `FORMAT/PL` (phred-scaled likelihoods) |
| `.` | Variable / unspecified | Generic notes |

On a multi-allelic record, `INFO/AC` with `Number=A` is a comma-separated vector — `AC=10,5` means 10 copies of the first ALT and 5 of the second. Filter expressions operating on `Number=A` fields must use vector-aware syntax (`AC[0]`, `MIN(AC)`, `COUNT(AC>=10)`) rather than scalar comparisons.

## Normalization

A "normalized" VCF has its variants in canonical form:

1. **Left-aligned**: each indel's representation is shifted to the leftmost position consistent with the reference genome. Without left-alignment, the same biological indel can have multiple textual representations and fail to match across call sets.
2. **Decomposed (split)**: multi-allelic records are split into one record per ALT allele.
3. **Parsimonious**: the minimum number of bases that disambiguates REF and ALT.

The bcftools normalization command is:

    bcftools norm -f reference.fa -m - input.vcf.gz

`-f` provides the reference genome for left-alignment; `-m -` splits multi-allelics (`-m +` joins them back). For deduplication after split, pipe through `bcftools norm -d none` (or `-d any`).

After splitting, INFO fields with `Number=A` are unfolded so each new biallelic record carries the per-allele value that originally lived at the corresponding vector position. INFO fields with `Number=1` are duplicated unchanged into each split record.

## 1000 Genomes Project Phase 3 INFO schema

The Phase 3 V5b genotype VCFs (release 20130502, GRCh37) use the following INFO fields. Filter expressions in this corpus reference these tag names:

| Tag | Number | Description |
|---|---|---|
| `AC` | A | Allele count for each ALT |
| `AN` | 1 | Total number of alleles called |
| `AF` | A | Overall alternate-allele frequency (`AC/AN`) |
| `NS` | 1 | Number of samples with genotype |
| `DP` | 1 | Total read depth (combined across samples) |
| `EAS_AF` | A | Allele frequency in East Asian super-population |
| `AMR_AF` | A | Allele frequency in admixed-American super-population |
| `AFR_AF` | A | Allele frequency in African super-population |
| `EUR_AF` | A | Allele frequency in European super-population |
| `SAS_AF` | A | Allele frequency in South Asian super-population |
| `VT` | . | Variant type: `SNP`, `INDEL`, `SV` |
| `EX_TARGET` | 0 | Flag: variant inside Gencode v12 exome target |
| `MULTI_ALLELIC` | 0 | Flag: site is multi-allelic |
| `END` | 1 | End coordinate (for symbolic/SV alleles) |

Population-specific AFs (`*_AF`) are independently computed per super-population and are independent of the global `AF`. A variant common in one super-population can be rare in another; comparisons across `*_AF` tags are the basis of selection-scan and population-differentiation analyses.

## Chromosome-name conventions

Two conventions coexist in human-genome VCFs:

- **No prefix**: `1, 2, …, 22, X, Y, MT` — used by 1000 Genomes Phase 3, Ensembl, GRC.
- **With prefix**: `chr1, chr2, …, chr22, chrX, chrY, chrM` — used by UCSC, GENCODE.

Region queries (`bcftools view -r`) must match the chromosome naming used in the file's header. Querying `-r chr22:1-100` against a no-prefix file silently returns zero records; the file's actual header listing should be inspected with `bcftools view -h | head` or `tabix -l`.

## Output formats and indexing

`bcftools view -O <FMT>` controls output:

- `-O v` — uncompressed VCF
- `-O z` — bgzip-compressed VCF (`.vcf.gz`)
- `-O b` — uncompressed BCF
- `-O u` — uncompressed BCF for piping (avoids gzip overhead between pipeline stages)

A bgzip-compressed VCF is index-ready via `tabix -p vcf file.vcf.gz`, producing `file.vcf.gz.tbi`. Many downstream tools require the index alongside the data file.

`bcftools view -O z -o filtered.vcf.gz` writes a compressed VCF; the index must be created in a separate `tabix` invocation or by adding `--write-index` (recent bcftools versions) to bcftools view itself.
