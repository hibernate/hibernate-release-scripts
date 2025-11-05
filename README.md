# hibernate-release-scripts
Release scripts for Hibernate projects

These release scripts are used by our Jenkins release jobs.

The release job that uses these scripts, has to checkout them as follows: 
```groovy
dir('.release/scripts') {
    sh 'git clone https://github.com/hibernate/hibernate-release-scripts.git .'
}
```
