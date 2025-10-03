'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'

interface User {
  id: number
  username: string
  email: string
  role: string
}

interface Project {
  id: number
  name: string
  description: string
  status: string
}

export default function Dashboard() {
  const [user, setUser] = useState<User | null>(null)
  const [projects, setProjects] = useState<Project[]>([])
  const router = useRouter()

  useEffect(() => {
    const userStr = localStorage.getItem('user')
    if (!userStr) {
      router.push('/')
      return
    }

    const userData = JSON.parse(userStr)
    setUser(userData)

    fetch(`/api/projects?userId=${userData.id}`)
      .then(res => res.json())
      .then(data => setProjects(data.projects || []))
      .catch(err => console.error(err))
  }, [router])

  const handleLogout = () => {
    localStorage.removeItem('user')
    router.push('/')
  }

  if (!user) return <div className="min-h-screen bg-black flex items-center justify-center"><div className="text-white">Loading...</div></div>

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-black to-gray-900 text-white">
      <nav className="bg-gray-800 border-b border-gray-700">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-bold">Antimony Labs Console</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-gray-300">{user.username}</span>
              <button
                onClick={handleLogout}
                className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h2 className="text-3xl font-bold">Welcome, {user.username}!</h2>
          <p className="text-gray-400 mt-2">Your projects and contributions</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {projects.length === 0 ? (
            <div className="col-span-full bg-gray-800 rounded-lg p-8 text-center">
              <p className="text-gray-400">No projects yet. Start building!</p>
            </div>
          ) : (
            projects.map((project) => (
              <div key={project.id} className="bg-gray-800 rounded-lg p-6 hover:bg-gray-750 transition">
                <h3 className="text-xl font-semibold mb-2">{project.name}</h3>
                <p className="text-gray-400 mb-4">{project.description}</p>
                <div className="flex items-center justify-between">
                  <span className={`px-3 py-1 rounded text-sm ${
                    project.status === 'active' ? 'bg-green-600' :
                    project.status === 'in_development' ? 'bg-blue-600' :
                    'bg-gray-600'
                  }`}>
                    {project.status}
                  </span>
                  <button className="text-blue-400 hover:text-blue-300">
                    Open →
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </main>
    </div>
  )
}
