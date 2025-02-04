import test from 'unit.js'
import { PROVIDER_UUID } from '@mds-core/mds-test-data'
import express from 'express'
import { AuthorizationHeaderApiAuthorizer } from '../index'

const PROVIDER_SCOPES = 'admin:all'
const ADMIN_AUTH = `basic ${Buffer.from(`${PROVIDER_UUID}|${PROVIDER_SCOPES}`).toString('base64')}`

describe('Test API Authorizer', () => {
  it('No Authorizaton', done => {
    const authorizer = AuthorizationHeaderApiAuthorizer({} as express.Request)
    test.value(authorizer).is(null)
    done()
  })

  it('Invalid Authorizaton Scheme', done => {
    const authorizer = AuthorizationHeaderApiAuthorizer({ headers: { authorization: 'invalid' } } as express.Request)
    test.value(authorizer).is(null)
    done()
  })

  it('Basic Authorizaton', done => {
    const authorizer = AuthorizationHeaderApiAuthorizer({ headers: { authorization: ADMIN_AUTH } } as express.Request)
    test
      .object(authorizer)
      .hasProperty('principalId', PROVIDER_UUID)
      .hasProperty('scope', PROVIDER_SCOPES)
    done()
  })

  it('Bearer Authorizaton', done => {
    const authorizer = AuthorizationHeaderApiAuthorizer({
      headers: { authorization: ADMIN_AUTH }
    } as express.Request)
    test
      .object(authorizer)
      .hasProperty('principalId', 'c8051767-4b14-4794-abc1-85aad48baff1')
      .hasProperty('scope', PROVIDER_SCOPES)
    done()
  })
})
