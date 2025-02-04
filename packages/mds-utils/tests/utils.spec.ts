/*
    Copyright 2019 City of Los Angeles.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
 */

import test from 'unit.js'
import { routeDistance } from '../utils'

const Boston = { lat: 42.360081, lng: -71.058884 }
const LosAngeles = { lat: 34.052235, lng: -118.243683 }
const BostonToLA = 4169605.469765776

describe('Tests Utilities', () => {
  it('routeDistance: Verifies single point', done => {
    test.value(routeDistance([Boston])).is(0)
    done()
  })

  it('routeDistance: Verifies 2 points', done => {
    test.value(routeDistance([Boston, LosAngeles])).is(BostonToLA)
    done()
  })

  it('routeDistance: Verifies 2+ points', done => {
    test.value(routeDistance([Boston, LosAngeles, Boston])).is(BostonToLA * 2)
    done()
  })
})
