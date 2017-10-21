
# Contributing

Tanya is a project in active development, therefore any help is appreciated. Thank you for considering contributing
to it, feel welcome.
These guidelines describe ways to get started.


## Ways to get involved

* **Reporting a problem**: [Report](https://github.com/caraus-ecms/tanya/issues) bugs and usage problems you
encounter.
* **Fixing issues**: [The bug tracker](https://github.com/caraus-ecms/tanya/issues) contains a list of issues you
can work on.
* **Documentation**: You can improve API documentation by correcting grammar errors, completing existing texts and
writing new ones, or providing usage examples.
* **Testing**: Test coverage is important for a library. Writing tests is not only helpful, but is also a great way
to get a feel for how tanya works.
* **Adding new features**: Tanya is a growing library. If you think some feature is missing, you can suggest
and implement this.


## Opening an issue

If you have found a bug, an error, have some question, or suggestion,
[Open an issue](https://github.com/caraus-ecms/tanya/issues). I'll try to answer as soon as I can. There is also a
list of open issues that mirror the current development process and progress. If you're looking for a challenge, just
pick an issue you are interested in and start working on it. Fill free to comment on the issue to get more
information.

You can also look at the [milestones](https://github.com/Dlackware/gnome/milestones) to see what is planned for a
specific release.


## Contribution process

### Creating a pull request

I accept GitHub pull requests. Creating a pull request is like sending a patch with the suggested change.
First you have to [fork](https://guides.github.com/activities/forking/) the repository. Clone your fork locally
with `git clone` and create a new branch where you want to work. For example:

```shell
git checkout -b bugfix-x
```
Commit your changes to your fork:

```shell
git commit -m "Fix X"
git push -u origin bugfix-x
```

After that if you visit your fork on GitHub, GitHub will suggest to create pull request. Just follow the steps
described on GitHub to finish the process. See
[Using Pull Requests](https://help.github.com/articles/about-pull-requests/) for more information.

Please ensure that your fork is even with the upstream (original) repository. If not, you have to rebase your branch
on upstream/master before submitting the pull request. See [Syncing a fork](https://help.github.com/articles/syncing-a-fork/) for a
step-by-step guide.

### Fixing a bug

Add a unit test that demonstrates the bug along with a short description or link to the original bug.

### Adding new features

* Use Ddoc to document the feature.
* Add some unit tests to prevent bugs.
* [Documented D unit tests](https://dlang.org/spec/ddoc.html#using_ddoc_to_generate_examples) go into the documentation and can be used as an usage
example. These tests should be readable and not complicated since they demonstrate how the feature is supposed to work.
* More advanced tests should be put into a separate not documented unittest block.

### Writing unit tests

```d
///
unittest
{
    // A documented unit test has three slashes in front of it.
}

// Issue ##: https://github.com/caraus-ecms/tanya/issues/##.
unittest
{
    // Not documented unit test may still have a description.
}
```

### Style guide

Make sure your changes follow [The D Style](https://dlang.org/dstyle.html) (including
[Additional Requirements for Phobos](https://dlang.org/dstyle.html#phobos)).

You can also use [dscanner](https://github.com/dlang-community/D-Scanner) to test the new code against the
most guidlines. The root of this repository contains
[dscanner.ini](https://github.com/caraus-ecms/tanya/blob/master/dscanner.ini), configuration file with settings for an
automatic style check. Just go to the top-level directory and issue (this assumes `dscanner` is installed in your
system):

```shell
dscanner --styleCheck source
```

## Questions and suggestions

* [Open an issue](https://github.com/caraus-ecms/tanya/issues)
* [Send an email](mailto:info@caraus.de)
