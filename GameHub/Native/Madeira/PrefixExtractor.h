#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** Extract a gzip-compressed ustar tarball into dest_dir.
 *  Returns 0 on success, -1 on failure.
 */
int madeira_extract_prefix_tgz(const char *tgz_path, const char *dest_dir);

#ifdef __cplusplus
}
#endif
