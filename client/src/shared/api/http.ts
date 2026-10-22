const baseUrl = import.meta.env.VITE_APPLICATION_SERVER_URL

if (!baseUrl) {
  throw new Error('APPLICATION_SERVER_URL is not configured')
}

export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

const getErrorMessage = async (response: Response) => {
  try {
    const payload = (await response.json()) as { error?: unknown }

    if (typeof payload.error === 'string' && payload.error) {
      return payload.error
    }
  } catch {
    // The API can return an empty response for some errors.
  }

  return `Запрос завершился с ошибкой ${response.status}`
}

export const request = async <T>(path: string, options?: RequestInit) => {
  let response: Response

  try {
    response = await fetch(`${baseUrl}/api${path}`, {
      ...options,
      headers: {
        ...(options?.body ? { 'Content-Type': 'application/json' } : {}),
        ...options?.headers,
      },
    })
  } catch {
    throw new ApiError('Не удалось связаться с сервером', 0)
  }

  if (!response.ok) {
    throw new ApiError(await getErrorMessage(response), response.status)
  }

  if (response.status === 204) {
    return undefined as T
  }

  return (await response.json()) as T
}
