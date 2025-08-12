#!/usr/bin/env node

import { readFileSync, statSync } from 'fs'
import { spawn } from 'child_process'
import { load } from 'js-yaml'

function loadStacks() {
  try {
    const yamlContent = readFileSync("stacks.yaml", 'utf8')
    const parsed = load(yamlContent)
    return parsed.default || []
  } catch (error) {
    console.error("Error loading stacks.yaml:", error.message)
    return []
  }
}

function folderExists(path) {
  try {
    const stat = statSync(path)
    return stat.isDirectory()
  } catch {
    return false
  }
}

function runCommand(cmd, args = []) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, {
      stdio: ['inherit', 'pipe', 'pipe']
    })
    
    let stdout = ''
    let stderr = ''
    
    child.stdout.on('data', (data) => {
      stdout += data.toString()
    })
    
    child.stderr.on('data', (data) => {
      stderr += data.toString()
    })
    
    child.on('close', (code) => {
      if (code !== 0) {
        console.error(`Command failed: ${cmd} ${args.join(' ')}`)
        console.error(`Error: ${stderr.trim()}`)
        resolve(false)
      } else {
        if (stdout.trim()) {
          console.log(stdout.trim())
        }
        resolve(true)
      }
    })
    
    child.on('error', (error) => {
      console.error(`Failed to run command: ${cmd} ${args.join(' ')}`, error.message)
      resolve(false)
    })
  })
}

async function processStacks() {
  console.log(`[${new Date().toISOString()}] Checking stacks...`)
  
  const stacks = loadStacks()
  
  if (stacks.length === 0) {
    console.log("No stacks found in configuration")
    return
  }
  
  for (const stack of stacks) {
    const { name, url } = stack
    const stackPath = `/stacks/${name}`
    
    console.log(`Checking stack: ${name}`)
    
    if (!folderExists(stackPath)) {
      console.log(`Stack folder ${stackPath} does not exist, cloning...`)
      
      // Run jj clone with depth 10
      const cloneSuccess = await runCommand("jj", [
        "git", "clone", 
        "--depth", "10",
        url,
        stackPath
      ])
      
      if (!cloneSuccess) {
        console.error(`Failed to clone ${name}`)
        continue
      }
      
      console.log(`Successfully cloned ${name}`)
    } else {
      console.log(`Stack folder ${stackPath} already exists`)
    }
    
    // TODO: hanlde watch mode
    // Run docker compose up in the stack directory
    console.log(`Running compose up for ${name}...`)
    const composeSuccess = await runCommand("docker", [
      "compose", 
      "-f", `${stackPath}/docker-compose.yaml`,
      "up", "-d"
    ])
    
    if (composeSuccess) {
      console.log(`Successfully started ${name}`)
    } else {
      console.error(`Failed to start ${name}`)
    }
  }
  
  console.log("Stack processing complete\n")
}

async function main() {    
    // Run immediately on start
    await processStacks()
}

main().catch(console.error)