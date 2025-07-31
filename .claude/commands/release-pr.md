# release-pr

Create a release PR following Ruby gem best practices.

## Steps to Execute

1. **Determine Version Bump**
   - Review the CHANGELOG.md "Unreleased" section
   - Determine the appropriate version bump based on Semantic Versioning:
     - MAJOR (x.0.0): Breaking changes
     - MINOR (0.x.0): New features, backward compatible
     - PATCH (0.0.x): Bug fixes only
   - Ask the user to confirm the version if unclear

2. **Create Release Branch**
   ```bash
   git checkout -b release/v<VERSION>
   ```

3. **Update Version**
   - Edit `lib/tastytrade/version.rb` to bump the version number

4. **Update CHANGELOG.md**
   - Move all entries from "Unreleased" to a new version section with today's date
   - Format: `## [X.Y.Z] - YYYY-MM-DD`
   - Create a new empty "Unreleased" section at the top with all subsections:
     ```markdown
     ## [Unreleased]
     
     ### Added
     - Nothing yet
     
     ### Changed
     - Nothing yet
     
     ### Deprecated
     - Nothing yet
     
     ### Removed
     - Nothing yet
     
     ### Fixed
     - Nothing yet
     
     ### Security
     - Nothing yet
     ```

5. **Commit Changes**
   ```bash
   git add lib/tastytrade/version.rb CHANGELOG.md
   git commit -m "Release v<VERSION>"
   ```

6. **Push Branch**
   ```bash
   git push -u origin release/v<VERSION>
   ```

7. **Create Pull Request**
   ```bash
   gh pr create --title "Release v<VERSION>" --body "## Release v<VERSION>

   This PR prepares the release of version <VERSION>.

   ### Changes
   - Bumped version to <VERSION>
   - Updated CHANGELOG.md with release date
   
   ### Release Checklist
   - [ ] Version number is correct
   - [ ] CHANGELOG.md is updated with all changes
   - [ ] All tests pass
   - [ ] RuboCop reports no offenses
   
   ### Post-Merge Steps
   After merging this PR:
   1. \`git checkout main && git pull\`
   2. \`git tag v<VERSION>\`
   3. \`git push --tags\`
   4. \`bundle exec rake release\`"
   ```

## Important Notes

- Do NOT run `rake release` as part of the PR - this happens after merge
- Ensure all tests pass before creating the PR
- Run RuboCop to ensure code quality
- The version in the PR title and body should NOT include the 'v' prefix (e.g., "0.2.0" not "v0.2.0")
- The git tag SHOULD include the 'v' prefix (e.g., "v0.2.0")

## Example

For a minor version bump from 0.1.0 to 0.2.0:
- Branch name: `release/v0.2.0`
- Commit message: `Release v0.2.0`
- PR title: `Release v0.2.0`
- Git tag (after merge): `v0.2.0`