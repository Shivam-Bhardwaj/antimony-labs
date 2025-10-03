import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'antimony',
  user: 'antimony',
  password: 'antimony123'
})

export async function POST(request: NextRequest) {
  try {
    const { email, password } = await request.json()

    const result = await pool.query(
      'SELECT id, username, email FROM users WHERE email = $1 AND password_hash = crypt($2, password_hash)',
      [email, password]
    )

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Invalid credentials' },
        { status: 401 }
      )
    }

    const user = result.rows[0]

    await pool.query(
      'UPDATE users SET last_login = NOW() WHERE id = $1',
      [user.id]
    )

    return NextResponse.json({ user })
  } catch (error) {
    console.error('Login error:', error)
    return NextResponse.json(
      { error: 'Server error' },
      { status: 500 }
    )
  }
}
