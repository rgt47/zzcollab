# Content-Addressable Docker Image Caching

## Abstract

This document describes a content-addressable caching mechanism for Docker
images in the zzcollab framework. By computing a cryptographic hash of the
Dockerfile and renv.lock files, zzcollab can detect when an identical image
already exists locally and reuse it instead of rebuilding. This optimization
reduces build times from several minutes to under one second for projects
sharing identical configurations.

## Problem Statement

Research teams using zzcollab frequently create multiple projects with
identical computational environments. For example:

- A team may have several analysis projects using the same `analysis` profile
- Training workshops create dozens of identical student workspaces
- CI/CD pipelines rebuild images that haven't actually changed

Each redundant build wastes time and computational resources:

| Component | Typical Build Time |
|-----------|-------------------|
| Base image pull | 30-60 seconds |
| System dependencies | 1-2 minutes |
| TinyTeX installation | 60-90 seconds |
| R package installation | 2-5 minutes |
| **Total** | **5-10 minutes** |

When a user runs `zzc analysis` in a new project directory, the entire build
process executes even if an identical image was built minutes earlier for a
different project.

## Solution: Content-Addressable Image Caching

### Core Concept

The solution applies content-addressable storage principles to Docker images.
Rather than identifying images solely by name (which varies per project), we
also identify them by the hash of their build inputs.

**Key insight**: Two Dockerfiles with identical content will produce
functionally identical images. By labeling images with a hash of their build
inputs, we can detect duplicates before building.

### Implementation

#### 1. Hash Computation

When building an image, zzcollab computes a SHA-256 hash of the combined
Dockerfile and renv.lock content:

```bash
compute_dockerfile_hash() {
    local hash=""
    if [[ -f "Dockerfile" ]] && [[ -f "renv.lock" ]]; then
        hash=$(cat Dockerfile renv.lock | shasum -a 256 | cut -d' ' -f1)
    elif [[ -f "Dockerfile" ]]; then
        hash=$(shasum -a 256 Dockerfile | cut -d' ' -f1)
    fi
    echo "$hash"
}
```

The hash includes both files because:

- **Dockerfile**: Defines the base image, system dependencies, and build steps
- **renv.lock**: Defines the exact R package versions to install

Together, these files fully specify the computational environment.

#### 2. Image Labeling

When building a new image, zzcollab adds a label containing the hash:

```bash
docker build --label zzcollab.dockerfile.hash=$dockerfile_hash -t $project_name .
```

This label persists with the image and can be queried later.

#### 3. Cache Lookup

Before building, zzcollab searches local images for a matching hash:

```bash
find_cached_image() {
    local target_hash="$1"
    docker images --format '{{.ID}}' | while read -r id; do
        local label
        label=$(docker inspect --format \
            '{{index .Config.Labels "zzcollab.dockerfile.hash"}}' "$id")
        if [[ "$label" == "$target_hash" ]]; then
            echo "$id"
            break
        fi
    done
}
```

#### 4. Tag Reuse

If a cached image is found, zzcollab simply tags it with the new project name:

```bash
if [[ -n "$cached_image" ]]; then
    docker tag "$cached_image" "$project_name:latest"
    log_success "Found cached image with identical configuration"
    return 0
fi
```

### Build Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    zzc analysis                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         Compute hash of Dockerfile + renv.lock              │
│         hash = SHA256(Dockerfile || renv.lock)              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│     Search local images for zzcollab.dockerfile.hash        │
│     matching computed hash                                  │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
        Found match                  No match
              │                           │
              ▼                           ▼
┌─────────────────────────┐  ┌─────────────────────────────────┐
│  docker tag             │  │  docker build                   │
│  $cached_id             │  │  --label zzcollab.dockerfile.   │
│  $project_name:latest   │  │         hash=$hash              │
│                         │  │  -t $project_name .             │
│  Time: <1 second        │  │                                 │
└─────────────────────────┘  │  Time: 5-10 minutes             │
                             └─────────────────────────────────┘
```

## Performance Impact

| Scenario | Without Caching | With Caching |
|----------|----------------|--------------|
| First project build | 5-10 min | 5-10 min |
| Second identical project | 5-10 min | <1 sec |
| Workshop with 20 students | 100-200 min | 5-10 min |
| CI/CD unchanged Dockerfile | 5-10 min | <1 sec |

**Speedup**: Up to 600x for cached builds.

## Design Considerations

### Why Hash Both Dockerfile and renv.lock?

The Dockerfile alone is insufficient because:

1. The `COPY renv.lock renv.lock` instruction copies the file's content
2. Two projects with identical Dockerfiles but different renv.lock files
   produce different images
3. Package versions significantly affect reproducibility

### Why Not Use Docker's Built-in Cache?

Docker's layer cache operates differently:

- **Layer cache**: Reuses intermediate layers during a single build
- **Content-addressable cache**: Reuses complete images across projects

Docker's cache doesn't help when:

- Building in a different directory (different build context)
- The project name differs (different image tag)
- The build context has any file changes

Our solution works at the image level, not the layer level.

### Hash Collision Considerations

SHA-256 produces a 256-bit hash, making collisions astronomically unlikely
(probability ~2^-128 for a collision). For practical purposes, hash matches
indicate identical build inputs.

### Label Storage

Labels are stored in the image's configuration metadata, adding negligible
overhead (~100 bytes). They persist through:

- Image exports/imports
- Registry pushes/pulls
- Container creation

## Limitations

1. **First build still required**: The optimization only helps subsequent
   builds with identical configurations.

2. **Local cache only**: The current implementation searches local images.
   It does not query remote registries.

3. **Exact match required**: Any difference in Dockerfile or renv.lock
   produces a different hash, triggering a full rebuild.

4. **Build context not hashed**: Files copied into the image (beyond
   renv.lock) are not included in the hash. This is intentional—source
   code changes shouldn't invalidate the environment image.

## Future Enhancements

### Registry-Based Cache

Extend cache lookup to query Docker registries:

```bash
# Future: check registry for matching hash
docker manifest inspect registry/zzcollab-cache:$hash
```

### Partial Hash Matching

Allow partial matches for incremental updates:

- Same base image hash → reuse base layers
- Same system deps hash → reuse system layer
- Different renv.lock → only rebuild R packages

### Cache Cleanup

Implement garbage collection for old cached images:

```bash
zzc cache prune --older-than 30d
```

## Conclusion

Content-addressable image caching provides substantial time savings for
zzcollab users working with multiple projects sharing identical
configurations. By applying cryptographic hashing to build inputs and
storing the hash as an image label, zzcollab can detect and reuse existing
images in under one second, avoiding redundant builds that would otherwise
take 5-10 minutes.

The implementation is transparent to users—the same `zzc analysis` command
works whether building fresh or reusing a cached image. This optimization
particularly benefits research teams, training workshops, and CI/CD
pipelines where identical environments are common.

## References

- Docker BuildKit documentation: https://docs.docker.com/build/buildkit/
- Content-addressable storage: https://en.wikipedia.org/wiki/Content-addressable_storage
- renv package management: https://rstudio.github.io/renv/
