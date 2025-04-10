pipeline {
  agent any
  environment {
    PATH = "/usr/local/bin:/usr/bin:/bin:$PATH"
  }
  parameters {
    string(name: 'TARGET_IP', defaultValue: '', description: 'Target IP/hostname')
    choice(name: 'CREDENTIALS', choices: ['ubuntu-dev-creds', 'mac-dev-creds'], description: 'Select SSH credentials')
    choice(name: 'SUDO_CREDENTIALS', choices: ['ubuntu-sudo-creds', 'mac-sudo-creds'], description: 'Select sudo password credentials')
    booleanParam(name: 'DO_CLEAN', defaultValue: false, description: 'Clean after update')
  }
  stages {
    stage('Preparation') {
      steps {
        script {
          if (params.TARGET_IP == 'target-host') {
            error("TARGET_IP is set to the default placeholder. Please provide a valid target hostname or IP.")
          }
          def sshpassPath = sh(script: 'which sshpass', returnStdout: true).trim()
          if (!sshpassPath) {
            error("sshpass not found on Jenkins node")
          }
          env.SSHPASS_CMD = sshpassPath
          echo "Using sshpass at: ${env.SSHPASS_CMD}"
        }
        checkout scm
      }
    }
    stage('Deploy Script') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: params.CREDENTIALS,
                                            keyFileVariable: 'SSH_KEY',
                                            usernameVariable: 'SSH_USER')]) {
          sshagent(credentials: [params.CREDENTIALS]) {
            script {
              def target = "${SSH_USER}@${params.TARGET_IP}"
              echo "Deploying to ${target}"
              sh "scp -o StrictHostKeyChecking=no packages_update.sh ${target}:~/packages_update.sh"
              sh "ssh -o StrictHostKeyChecking=no ${target} 'chmod +x ~/packages_update.sh'"
            }
          }
        }
      }
    }
    stage('Execute Update') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: params.CREDENTIALS,
                                            keyFileVariable: 'SSH_KEY',
                                            usernameVariable: 'SSH_USER')]) {
          sshagent(credentials: [params.CREDENTIALS]) {
            script {
              def target = "${SSH_USER}@${params.TARGET_IP}"
              echo "Determining remote OS on ${target}"
              def remoteOS = sh(script: "ssh -o StrictHostKeyChecking=no ${target} 'uname -s'", returnStdout: true).trim()
              env.REMOTE_OS = remoteOS
              echo "Remote OS detected: ${env.REMOTE_OS}"

              def baseCmd = 'CLEAN=' + params.DO_CLEAN + ' ~/packages_update.sh'
              if (env.REMOTE_OS == 'Darwin') {
                echo "Executing update on Darwin system without sudo"
                sh "ssh -o StrictHostKeyChecking=no ${target} '${baseCmd}'"
              } else {
                echo "Executing update on ${env.REMOTE_OS} system with sudo"
                withCredentials([usernamePassword(credentialsId: params.SUDO_CREDENTIALS,
                                                  usernameVariable: 'SUDO_USER',
                                                  passwordVariable: 'SUDO_PASS')]) {
                  def remoteCmd = ' echo ' + SUDO_PASS + ' | sudo -S ' + baseCmd
                  sh 'ssh -o StrictHostKeyChecking=no ' + target + ' \'' + remoteCmd + '\''
                }
              }
            }
          }
        }
      }
    }
  }
  post {
    always {
      script {
        withCredentials([sshUserPrivateKey(credentialsId: params.CREDENTIALS,
                                            keyFileVariable: 'SSH_KEY',
                                            usernameVariable: 'SSH_USER')]) {
          sshagent(credentials: [params.CREDENTIALS]) {
            def target = "${SSH_USER}@${params.TARGET_IP}"
            echo "Retrieving update log from ${target}"
            sh "scp -o StrictHostKeyChecking=no ${target}:~/update.log update.log || echo 'update.log not retrieved'"
            if (fileExists('update.log')) {
              def log = readFile('update.log')
              if (log.toLowerCase().contains("warning") || log.toLowerCase().contains("error")) {
                error("Warnings or errors detected in update.log")
              } else {
                echo "Execution log:\n${log}"
                echo "No warnings/errors detected; cleaning up remote files..."
                sh "ssh -o StrictHostKeyChecking=no ${target} 'rm -f ~/packages_update.sh ~/update.log'"
              }
            } else {
              echo "Warning: update.log not retrieved. Cleaning up deployed script only..."
              sh "ssh -o StrictHostKeyChecking=no ${target} 'rm -f ~/packages_update.sh'"
            }
          }
        }
      }
    }
  }
}