import { cleanup, render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { afterEach, expect, test, vi } from 'vitest'

import { AppHeader } from '../components/app-header'
import { PublicHeader } from '../components/public-header'

vi.mock('@tanstack/react-router', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@tanstack/react-router')>()
  return {
    ...actual,
    Link: (props: {
      to: string
      children?: ReactNode
      className?: string
      title?: string
    }) => (
      <a href={props.to} className={props.className} title={props.title}>
        {props.children}
      </a>
    ),
    useNavigate: () => vi.fn(),
    useRouterState: () => ({ location: { pathname: '/' } }),
  }
})

vi.mock('@/components/layout/components/header', () => ({
  Header: (props: { children: ReactNode }) => <header>{props.children}</header>,
}))

vi.mock('@/components/layout/components/system-brand', () => ({
  SystemBrand: () => <div>System brand</div>,
}))

vi.mock('@/components/layout/components/top-nav', () => ({
  TopNav: () => null,
}))

vi.mock('@/features/system-update/system-update-action', () => ({
  SystemUpdateAction: () => (
    <button type='button' aria-label='system update entry sentinel' />
  ),
}))

vi.mock('@/hooks/use-notifications', () => ({
  useNotifications: () => ({
    popoverOpen: false,
    setPopoverOpen: vi.fn(),
    activeTab: 'notice',
    setActiveTab: vi.fn(),
    notice: '',
    announcements: [],
    unreadCount: 0,
    loading: false,
  }),
}))

vi.mock('@/hooks/use-system-config', () => ({
  useSystemConfig: () => ({
    systemName: 'Test',
    logo: '',
    loading: false,
    logoLoaded: true,
  }),
}))

vi.mock('@/hooks/use-top-nav-links', () => ({
  useTopNavLinks: () => [],
}))

afterEach(cleanup)

test('AppHeader does not render the system update entry', () => {
  render(
    <AppHeader
      rightContent={<div />}
      showTopNav={false}
      showSearch={false}
      showNotifications={false}
      showConfigDrawer={false}
      showProfileDropdown={false}
    />
  )

  expect(
    screen.queryByRole('button', { name: 'system update entry sentinel' })
  ).not.toBeInTheDocument()
})

test('PublicHeader does not render the system update entry', () => {
  render(
    <PublicHeader
      showAuthButtons={false}
      showNotifications={false}
      showLanguageSwitcher={false}
      showThemeSwitch={false}
    />
  )

  expect(
    screen.queryByRole('button', { name: 'system update entry sentinel' })
  ).not.toBeInTheDocument()
})
