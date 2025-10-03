import { NextRequest, NextResponse } from 'next/server'
import { Pool } from 'pg'

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'antimony',
  user: 'antimony',
  password: 'antimony123'
})

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const userId = searchParams.get('userId')

    if (!userId) {
      return NextResponse.json(
        { error: 'User ID required' },
        { status: 400 }
      )
    }

    const result = await pool.query(
      `SELECT * FROM projects WHERE user_id = $1 ORDER BY created_at DESC`,
      [userId]
    )

    return NextResponse.json({ projects: result.rows })
  } catch (error) {
    console.error('Projects error:', error)
    return NextResponse.json(
      { error: 'Server error' },
      { status: 500 }
    )
  }
}
