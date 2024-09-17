package main

type price struct {
	timestamp int32
	price     int32
}

type session struct {
	prices []price
}

func (s *session) insert(timestamp, val int32) {
	s.prices = append(s.prices, price{timestamp, val})
}

func (s *session) query(min, max int32) int32 {
	var sum int64 = 0
	var count int64 = 0
	for _, p := range s.prices {
		if p.timestamp >= min && p.timestamp <= max {
			sum += int64(p.price)
			count++
		}
	}
	if count > 0 {
		return int32(sum / count)
	}
	return 0
}
