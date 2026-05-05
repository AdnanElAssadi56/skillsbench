---
name: bcftools-filter-expressions
description: Reference for the bcftools filter-expression language used by `bcftools view -i / -e`, `bcftools filter -i / -e`, and `bcftools query -i`. Documents the include/exclude polarity, the INFO/<TAG> and FORMAT/<TAG> field-access syntax, the available operators and functions, and the limits of the expression grammar (no abs(), no array indexing into vector fields). Use when applying any filter cascade to a VCF/BCF with bcftools.
---

# bcftools — Filter Expression Language

`bcftools` (samtools.github.io/bcftools/) is the canonical command-line toolkit for VCF/BCF manipulation, maintained by the Wellcome Sanger Institute. Its filter-expression language is shared across `bcftools view`, `bcftools filter`, `bcftools query`, and `bcftools annotate`. The grammar is small and strict; expressions that look correct in other languages frequently behave unexpectedly in bcftools because the dialect is its own.

The authoritative documentation for the expression grammar is the **EXPRESSIONS** section of `bcftools(1)` (`man bcftools` in any installation, or <https://samtools.github.io/bcftools/bcftools.html#expressions>).

## Include vs exclude (`-i` vs `-e`)

The two flags accept the same expression grammar but apply opposite polarity:

- `-i EXPR` — **include** records for which EXPR evaluates to true
- `-e EXPR` — **exclude** records for which EXPR evaluates to true

These are not synonyms with negation; they have different short-circuit behavior on missing fields. A bcftools filter that removes nothing or removes everything frequently has the wrong polarity rather than a wrong expression.

## Field access — INFO vs FORMAT vs FILTER

Every field reference in an expression must be qualified by where the field lives in the VCF record:

| Source | Syntax | Example |
|---|---|---|
| INFO column | `INFO/<TAG>` or `<TAG>` (when unambiguous) | `INFO/AF >= 0.05` |
| FORMAT column (per-sample) | `FORMAT/<TAG>` or `FMT/<TAG>` | `FMT/DP < 10` |
| FILTER column | `FILTER` | `FILTER="PASS"` |
| QUAL column | `QUAL` | `QUAL >= 30` |

A bare `<TAG>` in an expression is resolved by bcftools first as INFO, then as FORMAT, then as a contig name, then as a sample name. If both INFO and FORMAT contain a tag with the same name (`DP` is the canonical example), a bare `DP` matches the FORMAT field and produces per-sample evaluation, not the INFO/DP scalar. **Always qualify with `INFO/` or `FORMAT/` to avoid ambiguity.**

## Operators

Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`. String equality is single `=` or `==` (both accepted).

Arithmetic: `+`, `-`, `*`, `/`. Operate on numeric INFO scalars and on per-sample FORMAT values.

Logical: `&&` (and), `||` (or), `!` (not). Standard short-circuit.

Existence: `<TAG>!=""` tests presence of a string tag; `<TAG>!=999` (some sentinel) is not the standard way to test missingness — use `<TAG>!="."` for missing strings or rely on bcftools' missing propagation in numeric comparisons.

## Functions on vector fields

INFO fields with `Number=A`, `Number=R`, or `Number=G` are vector-valued. bcftools provides several aggregate functions:

- `MIN(<TAG>)`, `MAX(<TAG>)`, `AVG(<TAG>)`, `SUM(<TAG>)` — aggregate over the vector
- `COUNT(<expr>)` — count of vector elements satisfying the condition
- `<TAG>[0]`, `<TAG>[1]` — index into vector; `[*]` matches any element

For per-allele tags on multi-allelic sites (`Number=A`), `INFO/AC[0]` is the count for the first ALT allele, `[1]` for the second, etc.

## What the expression language does NOT have

Patterns that work in NumPy / Python / SQL but not in bcftools filter:

- **No `abs()`.** An absolute-value condition `|X − Y| ≥ T` is expressed as `(X - Y >= T || Y - X >= T)`, or equivalently as a paired comparison.
- **No `pow()`, no `sqrt()`, no transcendentals.** Only the four basic arithmetic operators on numerics.
- **No regular-expression operators.** String matching is exact. Use `bcftools view -e 'CHROM~"chr"'` shell-side or pre-process if pattern matching on string fields is needed; the `~` regex match is supported in some operators but not portable.
- **No NULL-coalescing.** Missing values propagate through arithmetic to missing, which evaluates to false in comparisons.
- **No conditional / ternary expressions.** `if … then … else …` is not part of the grammar.

## Combining with subset flags

`bcftools view` accepts both filter expressions (`-i`/`-e`) and structural subset flags (`--regions`, `--targets`, `--types`, `--samples`, `-m`, `-M`). The order of evaluation within a single `bcftools view` invocation is:

1. Region/target subsetting (index-based or stream-based positional restriction)
2. Type subsetting (`--types snps,indels,mnps,…`, `-m N -M N` for allele-count limits)
3. Filter expression (`-i` / `-e`)
4. Sample subsetting (`--samples`)

If sample subsetting changes which alleles are observed, INFO fields like `AC`, `AN`, `AF` are **not** automatically recomputed by `bcftools view`. Run `bcftools +fill-tags` (the fill-tags plugin, bundled with bcftools) afterwards to refresh them, or use `bcftools view --trim-alt-alleles` for allele-level cleanup. This is a frequent source of stale-statistics bugs: a downstream filter on `INFO/AF` after a `--samples` subset uses the original cohort's AF unless tags have been refilled.

## --regions vs --targets

Both flags restrict the variant set to a genomic interval, but they read input differently:

- `--regions` (`-r`) uses the tabix index to seek directly to the requested coordinates. Fast for large files; requires the `.tbi` (or `.csi`) index alongside the `.vcf.gz`.
- `--targets` (`-t`) streams the entire input file and discards records outside the requested coordinates. No index required; slower for whole-genome inputs.

For VCFs with a tabix index, `--regions` is the right default. `--targets` is needed only when the index is unavailable or when piping from a non-seekable source.

## Common-pitfall summary

- `-i 'AF >= 0.05'` — likely matches FORMAT/AF if it exists, not INFO/AF. Use `-i 'INFO/AF >= 0.05'`.
- `-e 'AF < 0.01'` and `-i 'AF >= 0.01'` are the same set when AF is always defined and never missing — they diverge on records where AF is missing (`-i` excludes missing, `-e` includes missing).
- An expression of the form `-i 'abs(INFO/X - INFO/Y) >= T'` will not parse — `abs()` is unsupported. Either expand to two paired comparisons (`-i 'INFO/X - INFO/Y >= T || INFO/Y - INFO/X >= T'`) or compute the difference upstream and filter on a single derived field.
- `-r chr22:1-100` against a VCF with `22` chromosome names (no `chr` prefix) — region selection silently returns 0 records. Match the chromosome naming used in the file's header.
- Sample subsetting (`--samples`) followed by a filter on `INFO/AF` — uses the pre-subset AF unless `bcftools +fill-tags -t AF` is run between.
