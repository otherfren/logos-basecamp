#!/usr/bin/env groovy

library 'status-jenkins-lib@add-logos-app-macos-signing-credentials'

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
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(
      numToKeepStr: '10',
      daysToKeepStr: '30',
      artifactNumToKeepStr: '1',
    ))
    disableConcurrentBuilds(
      abortPrevious: isPRBuild
    )
    copyArtifactPermission('/logos-app/*')
  }

  environment {
    PLATFORM = "macos/${getArch()}"
    ARTIFACT = "pkg/${utils.pkgFilename(name: 'LogosApp', ext: 'dmg', arch: getArch())}"
    NOTARIZED_ARTIFACT = "pkg/${utils.pkgFilename(name: 'LogosApp-notarized', ext: 'dmg', arch: getArch())}"
  }

  stages {
    stage('Build App Bundle') {
      steps {
        script {
          nix.flake("bin-macos-app")
        }
      }
    }

    stage('Smoke Test') {
      steps {
        script {
          sh '''
            ./result/LogosApp.app/Contents/MacOS/LogosApp -platform offscreen > /tmp/logos-launch.log 2>&1 &
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
        }
      }
    }

    stage('Package') {
      steps {
        script {
          sh 'mkdir -p pkg'
          sh 'ditto -c -k --keepParent result/LogosApp.app "${ARTIFACT}"'
        }
      }
    }

    stage('Sign & Notarize') {
      when {
        expression { utils.isReleaseBuild() }
      }
      steps {
        script {
          logos.signAndNotarizeApp(
            bundlePath: 'result/LogosApp.app',
            outputPath: env.NOTARIZED_ARTIFACT,
            timeout: '30m'
          )
        }
      }
    }

    stage('Upload') {
      steps {
        script {
          def uploadFile = utils.isReleaseBuild() ? env.NOTARIZED_ARTIFACT : env.ARTIFACT
          env.PKG_URL = s5cmd.upload(uploadFile)
          jenkins.setBuildDesc(DMG: env.PKG_URL)
        }
      }
    }

    stage('Archive') {
      steps {
        script {
          def uploadFile = utils.isReleaseBuild() ? env.NOTARIZED_ARTIFACT : env.ARTIFACT
          archiveArtifacts(uploadFile)
        }
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