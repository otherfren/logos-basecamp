#!/usr/bin/env groovy

library 'status-jenkins-lib@v1.9.41'

def isPRBuild = utils.isPRBuild()

pipeline {
  agent { label "macos && ${getArch()} && nix-2.24" }

  parameters {
    booleanParam(
      name: 'RELEASE',
      description: 'Decides whether release credentials are used.',
      defaultValue: params.RELEASE ?: false
    )
  }

  options {
    timestamps()
    ansiColor('xterm')
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(
      numToKeepStr: '10',
      daysToKeepStr: '30',
      artifactNumToKeepStr: '1',
    ))
    disableConcurrentBuilds(
      abortPrevious: isPRBuild
    )
    /* Allows combined build to copy */
    copyArtifactPermission('/logos-app/*')
  }

  environment {
    PLATFORM = "macos/${getArch()}"
    ARTIFACT = "pkg/${utils.pkgFilename(name: 'LogosApp', ext: 'dmg', arch: getArch())}"
  }

  stages {
    stage('Build DMG') {
      steps { script {
        nix.flake("dmg")
      } }
    }

    stage('Smoke Test') {
    steps { script {
      sh '''
        nix build '.#app'
        ./result/bin/LogosApp -platform offscreen > /tmp/logos-launch.log 2>&1 &
        APP_PID=$!
        sleep 10
        if grep -qE "QQmlApplicationEngine failed|module.*is not installed|Cannot assign|failed to load component" /tmp/logos-launch.log; then
          echo "Critical QML errors detected"
          cat /tmp/logos-launch.log
          kill $APP_PID 2>/dev/null
          exit 1
        fi
        if kill -0 $APP_PID 2>/dev/null; then
          kill $APP_PID
          echo "Smoke test passed"
        else
          echo "App crashed"
          cat /tmp/logos-launch.log
          exit 1
        fi
      '''
      } }
    }

    stage('Package') {
      steps {
        sh 'mkdir -p pkg'
        sh "cp result/LogosApp-*.dmg '${env.ARTIFACT}'"
      }
    }

    stage('Upload') {
      steps { script {
        env.PKG_URL = s5cmd.upload(env.ARTIFACT)
        jenkins.setBuildDesc(DMG: env.PKG_URL)
      } }
    }

    stage('Archive') {
      steps {
        archiveArtifacts(env.ARTIFACT)
      }
    }
  }

  post {
    success { script { github.notifyPR(true) } }
    failure { script { github.notifyPR(false) } }
    cleanup {
      cleanWs(disableDeferredWipeout: true)
      dir(env.WORKSPACE_TMP) { deleteDir() }
    }
  }
}

def getArch() {
  def tokens = Thread.currentThread().getName().split('/')
  for (def arch in ['x86_64', 'aarch64']) {
    if (tokens.contains(arch)) { return arch }
  }
}